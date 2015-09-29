# class Module
#   def was_attr_accessor(*args)
#     args.each do |arg|
#       self.class_eval %Q{
#         def #{arg}=(val)
#           @#{arg}_was = self.#{arg} if val != self.#{arg}
#           super
#         end
#       }

#       self.class_eval %Q{
#         def #{arg}_was
#           @#{arg}_was
#         end
#       }
#     end
#   end
# end

class Request < ActiveRecord::Base

  include ShiftTime
  default_scope { order(:date, :shift) }

  # was_attr_accessor :fulfilling_swap
  attr_accessor :save_pending

  belongs_to :user
  # has_one :twin_variant, class_name: "Variant", foreign_key: :variant_id
  # belongs_to :twin, class_name: "Variant", foreign_key: :variant_id

  belongs_to :fulfilling_swap, class_name: "Request", autosave: true
  belongs_to :availability, autosave: true # the one with the same shift where user != self.user
  scope :active, -> { future.seeking_offers.where.not(user: nil) }

  enum shift: ShiftTime::SHIFT_NAMES
  enum state: [ :seeking_offers, :received_offer, :sent_offer, :fulfilled ]

  validates :user, presence: true
  validates :shift, presence: true
  validates_with ShiftTimeValidator
  validate :no_availabilities_conflicts
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
      byebug
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

  def no_availabilities_conflicts(availabilities=user.availabilities)
    if availabilities.find {|a| a.start == self.start && a.free? }
      errors.add(:shift, "can't be the same as your own existing availability")
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

  # Relax this once we allow N-way swaps for N > 2
  # This seems like it should work with reflexive associations, but I can't make to happen
  # Assume the the initial call will have val == nil or val.fulfilling_swap.nil?
  def fulfilling_swap=(val)
    raise ArgumentError if val == self
    if self.fulfilling_swap != val
      other_to_leave = (fulfilling_swap && fulfilling_swap.fulfilling_swap == self) ? fulfilling_swap : nil
      other_to_join = (val && val.fulfilling_swap != self) ? val : nil
      super
      other_to_leave.fulfilling_swap = nil if other_to_leave
      other_to_join.fulfilling_swap = self if other_to_join
    end
  end

  def send_swap_offer_to(request_to_swap_with)
    transaction do
      # self.fulfilling_swap already set from controller; can't be inferred
      self.assign_attributes(
        state: :sent_offer,
        fulfilling_swap: request_to_swap_with,
        availability: request_to_swap_with.user.availabilities.find_by_shifttime!(self))
      request_to_swap_with.assign_attributes(
        state: :received_offer,
        fulfilling_swap: self,
        availability: self.user.find_or_initialize_availability_for(fulfilling_swap))
      if save # work around weird issue
        [self, request_to_swap_with].map {|r| r.persisted? && Request.exists?(r) }.all?
      end
    end
  end

  def accept_pending_swap
    [self, fulfilling_swap].each do |r|
      fulfilling_swap.state = :fulfilled
      r.each {|a| a.free = false }
    end
    save # confirm fulfilling_swap will autosave
  end

  def decline_pending_swap
  end

  # When one request changes state, there are a number of related changes to make to
  # other linked requests and availabilities. Handle them in the callbacks for consistency.
  before_validation do
    begin
      # if fulfilling_swap
      #   # Set up the inverse relationship
      #   if fulfilling_swap.fulfilling_swap != self
      #     fulfilling_swap.fulfilling_swap = self
      #   end

      #   if received_offer? || sent_offer?
      #     fulfilling_swap.state = opposite_state
      #   elsif fulfilling_swap.received_offer? || fulfilling_swap.sent_offer?
      #     self.state = fulfilling_swap.opposite_state
      #   end
      # end

      # if availability.nil? && !seeking_offers?
      #   if received_offer?
      #     self.availability = fulfilling_user.availabilities.find_by_shifttime!(self)
      #   elsif sent_offer?
      #     self.availability = fulfilling_user.find_or_create_availability_for!(self)
      #   end
      # end

      case state_change
      when ['seeking_offers', 'sent_offer']
        # # self.fulfilling_swap already set from controller; can't be inferred
        # self.availability = fulfilling_user.availabilities.find_by_shifttime!(self)
        # fulfilling_swap.assign_attributes(fulfilling_swap: self, state: :received_offer,
        #                                   availability: user.find_or_initialize_availability_for(fulfilling_swap))
      when ['seeking_offers', 'received_offer']
        # Nothing more to do; fulfilling_swap handled it
      when ['received_offer', 'fulfilled']
        # fulfilling_swap.state = :fulfilled
        # [availability, fulfilling_swap.availability].each {|a| a.free = false }
      when ['sent_offer', 'fulfilled']
        # Nothing more to do; fulfilling_swap handled it
      when ['seeking_offers', 'fulfilled'] # <== sub (no swap)
        availability.free = false
      when ['received_offer', 'seeking_offers']
        [self, fulfilling_swap].each do |r|
          if r.availability.implicitly_created?
            r.availability.mark_for_destruction
            r.availability.request = nil
          end
          r.assign_attributes(state: :seeking_offers, fulfilling_swap: nil, availability: nil)
          # r.save
        end
      when ['sent_offer', 'seeking_offers']
        # Nothing more to do
      else
        # raise "Unexpected state change: #{state_change.join(' to ')}"
      end

    rescue => e
      byebug
      true # If there are problems, flag them in validate
    end
  end

  # before_save do
  #   byebug
  #   puts "**** BEFORE SAVE for #{self.inspect} fulfilling_swap_was: #{fulfilling_swap_was}"
  #   if fulfilling_swap.nil? && fulfilling_swap_was
  #     if fulfilling_swap_was.changed? && !fulfilling_swap_was.save_pending
  #       fulfilling_swap_was.save_pending = true
  #       fulfilling_swap_was.save! # <== will trigger x's after_update to deal with its availability
  #     end
  #   end
  # end

  # make sure availabilities and

  # Why can't these be before_validation?
  after_update do

    # byebug
    # case state_change
    # when ['received_offer', 'fulfilled'], ['sent_offer', 'fulfilled'],
    #      ['seeking_offers', 'fulfilled'] # <== sub (no swap)
    #   if fulfilling_swap && !fulfilling_swap.fulfilled?
    #     fulfilling_swap.update!(state: :fulfilled)
    #   end
    #   availability.update!(free: false)
    # when ['received_offer', 'seeking_offers'], ['sent_offer', 'seeking_offers'] # offer declined
    #   if availability
    #     a = availability
    #     a.update!(request: nil)
    #     a.destroy! if a.implicitly_created?
    #   end

    #   if fulfilling_swap
    #     fulfilling_swap.update_attributes!(state: :seeking_offers, fulfilling_swap: nil)
    #     update!(fulfilling_swap: nil)
    #   end
    # when nil
    #   # Staying the same is OK
    # when ['seeking_offers', 'sent_offer'], ['seeking_offers', 'received_offer']
    #   # nothing more to do
    # else
    #   raise "Unexpected state change: #{state_change.join(' to ')}"
    # end
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

  # def self.categorize_matches(receivers_request, match_type_keys)
  #   Hash[match_type_keys.map {|k| [k, []] }].tap do |matching_requests_hash|
  #     active.each do |my_request|
  #       matched_key = match_type_keys.find do |match_type_key|
  #         my_request.match(receivers_request, MATCH_TYPE_MAP[match_type_key])
  #       end
  #       matching_requests_hash[matched_key] << receivers_request
  #     end
  #   end
  # end

  # self is the senders request
  def categorize_matches(receiver, match_type_keys)
    Hash[match_type_keys.map {|k| [k, []] }].tap do |matching_requests_hash|
      receiver.requests.active.each do |receivers_request|
        matched_key = match_type_keys.find do |match_type_key|
          self.match(receivers_request, MATCH_TYPE_MAP[match_type_key])
        end
        matching_requests_hash[matched_key] << receivers_request
      end
    end
  end

  # Match all the active requests in the current scope against all active requests
  def self.matching_requests(match_type)
    puts "******** self.matching_requests: matching #{active.count} against..."
    active.flat_map do |my_request|
      my_request.matching_requests(match_type)
    end
  end

  # Match self against all other active requests for match_type
  def matching_requests(match_type)
    puts "******** self.matching_requests: ...#{Request.unscoped.all.active.count} with #{match_type.inspect}"
    match_type = MATCH_TYPE_MAP[match_type] || match_type
    # Would work with all; limiting to active is an optimization
    Request.unscoped.all.active.select do |receivers_request|
      match(receivers_request, match_type)
    end
  end

  # self is the sender's request
  def match(receivers_request, senders_availability: nil, receivers_availability: nil)
    raise ArgumentError if receivers_availability.nil? || senders_availability.nil? # need ruby 2.1
    senders_availability_for_receivers_request = user.availability_state_for(receivers_request, looking_for_swaps: new_record?)
    receivers_availability_for_my_request = receivers_request.user.availability_state_for(self)
    puts "******** #{user} is #{senders_availability_for_receivers_request} #{receivers_request.user}'s for #{receivers_request}; #{receivers_request.user} is #{receivers_availability_for_my_request} for #{self.user}'s #{self}"
    [*receivers_availability].include?(receivers_availability_for_my_request) &&
      [*senders_availability].include?(senders_availability_for_receivers_request)
  end

  MATCH_TYPE_MAP = {
    offerable_swaps:    {senders_availability:   [:free, :potential],
                         receivers_availability:  :free},

    # The sender can make this into an ask_receiver_match match through their own actions
    # These are the ones we bother to even include in the sender's availability status page
    potential_matches:  {senders_availability:   [:free, :potential, :busy],
                         receivers_availability: [:free, :potential]},

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
    elsif received_offer? || sent_offer?
      "The request can't be changed while there is a pending offer."
    end
  end
    
  def fulfilling_user
    (availability || fulfilling_swap).user unless seeking_offers?
  end

  def fulfill_by_sub(subber)
    transaction do
      sub_availability = subber.find_or_create_availability_for!(self)
      update_attributes!(availability: sub_availability, state: :fulfilled)
    end
  end
  
  def pending?
    received_offer? && start.future?
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
    "#<Request id: #{self.id}, user[#{user_id}]: #{user ? user.name : 'nil'} , "\
      "date: #{date}, shift[#{self.class.shifts[shift]}]: #{shift}, "\
      "state[#{self.class.states[state]}]: #{state}#{fulfilling_swap_str}#{availability_str}>"
  end
end
