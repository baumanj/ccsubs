class Request < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  belongs_to :fulfilling_swap, class_name: "Request", autosave: true
  belongs_to :availability, autosave: true # the one with the same shift where user != self.user
  scope :active, -> { future.seeking_offers.where.not(user: nil) }
  scope :pending, -> { future.received_offer }

  enum shift: ShiftTime::SHIFT_NAMES
  enum state: [ :seeking_offers, :received_offer, :sent_offer, :fulfilled ]

  validates :user, presence: true, unless: :userless?
  validates :shift, presence: true
  validates_with ShiftTimeValidator
  validate do
    case state_change
    when ['seeking_offers', 'sent_offer']
    when ['seeking_offers', 'received_offer']
    when ['received_offer', 'fulfilled']
    when ['sent_offer', 'fulfilled']
    when ['seeking_offers', 'fulfilled'] # <== sub (no swap)
    when ['received_offer', 'seeking_offers']
    when ['sent_offer', 'seeking_offers']
    when nil
      if changed? && !new_record?
        errors.add(:state, "should change if request is changing")
      end
    else
      errors.add(:state, "unexpectedly changed from #{state_change.join(' to ')}")
    end

    # Seeking offers <-> no availability
    if seeking_offers? != availability.nil?
      errors.add(:availability, "must #{seeking_offers? ? "not be" : "be"} set if the state is #{state}")
    end

    # We can't check the seeking offers state here because we can't remove the connection between the
    # availability and request until we're sure we are comitting the change. See after_save

    if received_offer? || sent_offer?
      if fulfilling_swap
        # If one sent the offer, the other received it
        sender = sent_offer? ? self : fulfilling_swap
        unless sender.fulfilling_swap.received_offer?
          errors.add(:state, "must be #{opposite_state} if the fulfilling swap #{fulfilling_swap.state}")
        end
      else
        errors.add(:fulfilling_swap, "must be set if there is a pending offer") if fulfilling_swap.nil?
      end
    end

    if availability
      errors.add(:availability, "must be for the same shift") if self.start != availability.start
      errors.add(:availability, "must be for a different user") if self.user == availability.user
      if availability.free? == fulfilled?
        errors.add(:availability, "must #{fulfilled? ? 'not be' : 'be'} free")
      end
    end

    if fulfilled?
      errors.add(:fulfilling_user, "must be set if request is fulfilled") if fulfilling_user.nil?
    end

    if fulfilling_swap && fulfilling_swap.fulfilling_swap != self
      # Later this may be relaxed to be a cycle
      errors.add(:fulfilling_swap, "must be a reflexive relation between two requests")
    end
  end

  before_destroy do
    if !seeking_offers?
      errors.add(:state, "cannot be #{state}")
      false
    elsif start.past?
      errors.add(:start, "must be in the future")
      false
    end
  end

  def userless?
    false
  end

  def send_swap_offer_to(request_to_swap_with)
    with_lock do
      request_to_swap_with.lock!
      self.assign_attributes(
        state: :sent_offer,
        fulfilling_swap: request_to_swap_with,
        availability: request_to_swap_with.user.availabilities.find_by_shifttime!(self))
      request_to_swap_with.assign_attributes(
        state: :received_offer,
        fulfilling_swap: self,
        availability: self.user.find_or_initialize_availability_for(fulfilling_swap))
      save # fulfilling_swap and availabilities will be autosaved
    end
  end

  def accept_pending_swap
    if received_offer?
      with_lock do
        fulfilling_swap.lock!
        [self, fulfilling_swap].each do |r|
          r.state = :fulfilled
          r.availability.free = false
        end
        save
      end
    else
      errors.add(:state, "cannot be #{state} when accepting swap")
      false
    end
  end

  def decline_pending_swap
    if received_offer?
      with_lock do
        fulfilling_swap.lock!
        save_returns = [self, fulfilling_swap].map do |r|
          r.fulfilling_swap = nil
          r.state = :seeking_offers
          r.availability = nil
          r.save
        end
        save_returns.all?
      end
    else
      errors.add(:state, "cannot be #{state} when declining swap")
      false
    end
  end

  def fulfill_by_sub(subber)
    if seeking_offers?
      with_lock do
        sub_availability = subber.find_or_initialize_availability_for(self)
        if sub_availability.free?
          sub_availability.update!(free: false)
          update!(availability: sub_availability, state: :fulfilled)
        else
          errors.add(:subber, "must not be listed as unavailable")
          false
        end
      end
    else
      errors.add(:state, "cannot be #{state} when fulfilling by sub")
      false
    end
  end

  def opposite_state
    if received_offer?
      :sent_offer
    elsif sent_offer?
      :received_offer
    end
  end

  def self.active_slow
    Request.select(&:active_slow?)
  end

  # self is the senders request
  def categorize_matches(receiver, match_type_keys, future_requests, future_availabilities)
    Hash[match_type_keys.map {|k| [k, []] }].tap do |matching_requests_hash|
      receiver.requests.active.each do |receivers_request|
        matched_key = match_type_keys.find do |match_type_key|
          match_type = MATCH_TYPE_MAP[match_type_key]
          self.match(receivers_request,
                     senders_availability: match_type[:senders_availability],
                     receivers_availability: match_type[:receivers_availability],
                     preloaded_requests: future_requests,
                     preloaded_availabilities: future_availabilities)
        end
        matching_requests_hash[matched_key] << receivers_request if matched_key
      end
    end
  end

  # If there are any requests which have a pending offer, but whose time
  # has passed, decline them so the counterpart requests go back to the
  # seeking_offers state.
  def self.decline_past_offers
    past.received_offer.each do |request|
      other_request = request.fulfilling_swap
      if other_request.start.future? && request.decline_pending_swap
        UserMailer.notify_swap_decline(decliners_request: request,
                                       offerers_request: other_request).deliver_now
      end
    end

    past.sent_offer.each do |request|
      other_request = request.fulfilling_swap
      if other_request.start.future?
        other_request.decline_pending_swap
      end
    end
  end

  def self.nag_unresponded_offer_owners(days_old)
    Request.received_offer.where('updated_at < ?', days_old.to_i.days.ago).each do |request|
      UserMailer.send_unresponded_offer_nag(request).deliver_now
    end
  end

  # Find all the active requests which match active requests in the current scope
  # The current scope is typically a certain user's requests
  def self.matching_requests(match_type)
    match_type = MATCH_TYPE_MAP[match_type] || match_type
    future_requests = Request.future.to_a
    future_availabilities = Availability.future.to_a
    Request.unscoped.all.active.order(:date, :shift).select do |receivers_request|
      active.find do |my_request|
        my_request.match(receivers_request,
                         senders_availability: match_type[:senders_availability],
                         receivers_availability: match_type[:receivers_availability],
                         preloaded_requests: future_requests,
                         preloaded_availabilities: future_availabilities)
      end
    end
  end

  # Match self against all other active requests for match_type
  def matching_requests(match_type)
    match_type = MATCH_TYPE_MAP[match_type] || match_type
    future_requests = Request.future.to_a
    future_availabilities = Availability.future.to_a
    # Would work with all; limiting to active is an optimization
    Request.unscoped.all.active.order(:date, :shift).select do |receivers_request|
      match(receivers_request,
            senders_availability: match_type[:senders_availability],
            receivers_availability: match_type[:receivers_availability],
            preloaded_requests: future_requests,
            preloaded_availabilities: future_availabilities)
    end
  end

  # self is the sender's request
  # preloaded_{requests,availabilities} are ugly, but necessary to avoid hundreds of SQL queries
  def match(receivers_request, senders_availability:, receivers_availability:,
            preloaded_requests:, preloaded_availabilities:)
    senders_availability_for_receivers_request =
      user.availability_state_for(receivers_request, preloaded_requests, preloaded_availabilities)
    receivers_availability_for_my_request =
      receivers_request.user.availability_state_for(self, preloaded_requests, preloaded_availabilities)

    [*receivers_availability].include?(receivers_availability_for_my_request) &&
      [*senders_availability].include?(senders_availability_for_receivers_request)
  end

  MATCH_TYPE_MAP = {
    # The sender isn't necessarily explicity available, but they have no conflict and can indiciate
    # an implicit availability by offering a swap
    offerable_swaps:    {senders_availability:   [:free, :potential],
                         receivers_availability:  :free},

    # The sender needs to indicate whether they're available to either rule out a swap or to trigger
    # a query of the receiver's availability
    uncertain_avail:    {senders_availability:   [:potential],
                         receivers_availability: [:free, :potential]},

    # The sender can make this into an ask_receiver_match match through their own actions
    # These are the ones we bother to even include in the sender's availability status page
    potential_matches:  {senders_availability:   [:free, :potential, :busy],
                         receivers_availability: [:free, :potential]},

    # Both the sender and receiver are free; either could initiate
    full_match:         {senders_availability:   :free,
                         receivers_availability: :free},

    # The sender could send now, but if we had more info from the sender, the receiver could initiate
    ask_sender_match:   {senders_availability:   :potential,
                         receivers_availability: :free},
  }

  def offerable_swaps
    matching_requests(MATCH_TYPE_MAP[:offerable_swaps])
  end

  def potential_matches
    matching_requests(MATCH_TYPE_MAP[:potential_matches])
  end

  def uncertain_avail
    matching_requests(MATCH_TYPE_MAP[:uncertain_avail])
  end

  def active_slow?
    start.future? && seeking_offers? && user
  end

  def locked?
    !locked_reason.nil?
  end

  def locked_reason
    if start.past?
      "The request can't be changed after the shift has passed."
    elsif fulfilled?
      "The request can't be changed after it's been fulfilled."
    end
  end
    
  def fulfilling_user
    unless seeking_offers?
      fulfillment = (availability || fulfilling_swap)
      fulfillment ? fulfillment.user : "Unknown user"
    end
  end

  def inspect
    if (seeking_offers? != availability.nil?) || (availability && availability.start != start)
      # Something's wrong!
      availability_str = ", !!!AVAILABILITY!!!: #{availability.inspect}!!!"
    elsif availability
      availability_str = ", availability: #{availability.user.name}[#{availability.user.id}]'s availability[#{availability.id || 'new'}]"
    end
    if fulfilling_swap
      fulfilling_swap_str = ", fulfilling_swap: #{fulfilling_swap.user.name}[#{fulfilling_swap.user.id}]'s request[#{fulfilling_swap.id}]"
    end
    "#<Request id: #{self.id}, user[#{user_id}]: #{user ? user.name : 'nil'}, "\
      "date: #{date}, shift[#{self.class.shifts[shift]}]: #{shift}, "\
      "state[#{self.class.states[state]}]: #{state}#{fulfilling_swap_str}#{availability_str}>"
  end
end
