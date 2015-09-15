class Request < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  belongs_to :fulfilling_swap, class_name: "Request"
  belongs_to :availability

  validates :user, presence: true
  validates :shift, presence: true
  validates_with ShiftTimeValidator
  validate :no_availabilities_conflicts

  def no_availabilities_conflicts(availabilities=user.availabilities)
    if availabilities.find {|a| a.start == self.start && a.free? }
      errors.add(:shift, "can't be the same as your own existing availability")
    end
  end

  before_destroy do
    if !seeking_offers?
      errors.add(:state, "cannot be #{state}")
      return false
    elsif !future?
      errors.add(:start, "must be in the future")
      return false
    end
  end

  # When one request changes state, there are a number of related changes to make to
  # other linked requests and availabilities. Handle them in one place.
  after_update do
    # Just accepted an offer
    if state_changed? && fulfilled?      
        fulfilling_swap.update!(state: :fulfilled) unless fulfilling_swap.fulfilled?
        availability.update!(free: false)
    end

    # Just declined an offer
    if state_changed? && seeking_offers? && availability != nil
      a = availability
      a.update!(request: nil)
      a.destroy! if a.implicitly_created?
      unless fulfilling_swap.nil?
        fulfilling_swap.update_attributes!(state: :seeking_offers, fulfilling_swap: nil)
        update!(fulfilling_swap: nil)
      end
    end
  end    

  enum shift: ShiftTime::SHIFT_NAMES
  enum state: [ :seeking_offers, :received_offer, :sent_offer, :fulfilled ]

  def self.on_or_after(date)
    Request.where("date >= ?", date)
  end

  def self.all_seeking_offers
    Request.seeking_offers.where("date >= ?", Date.today).select {|r| r.start > Time.now }
  end

  # Find a reqest matching availability where the owner has availabilty to swap with one of
  # availability's owner's requests
  def self.swappable_with(availability)
    Request.where_shifttime(availability).find do |r|
      r.user.open_availabilities.find do |a|
        availability.user.open_requests {|r2| r2.start == a.start }
      end
    end
  end
  
  # Find the availabilities that aren't attached to requests and which belong
  # to users with open requests
  # We want the list of requests that the other users have, paired with their availability for THIS request
  def swap_candidates(other_user=nil)
    if other_user
      # find other user's requests that match this request's user's availabilities
      other_user.requests.select do |r| 
        self.user.open_availabilities.find {|a| a.start == r.start }
      end
    else
      # Return a list of users paired with their open requests so this request's user can
      # offer swaps, but exclude shifts this request's user is explicitly unavailable for
      others = Availability.where_shifttime(self).select(&:open?).map(&:user)
      others_requests = others.map {|o| o.open_requests.reject {|r| user.unavailable?(r) } }
      others.zip(others_requests).reject {|o, swappable_reqs| swappable_reqs.none? }
    end
  end

  def open?
    seeking_offers? && start.future?
  end

  def locked?
    return !locked_reason.nil?
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
    (availability || fulfilling_swap).user if fulfilled?
  end

  def fulfill_by_sub(subber)
    if subber.unavailable?(self)
      errors.add(:base, "#{subber} is not available to swap for #{self}.")
      return false
    end
    transaction do
      sub_availability = subber.availability_for!(self)
      update_attributes!(availability: sub_availability, state: :fulfilled)
    end
  end
  
  # my_availability is the self.user's availability to cover offer_request
  # self.availability will be set to the availibilty for covering this request
  def set_pending_swap(offer_request)
    my_availability = user.open_availability(offer_request)
    if my_availability.nil?
      errors.add("#{user}", " is not available to swap for #{offer_request}.")
      return false
    elsif !offer_request.open?
      errors.add(:offer_request, "Only open requests can be offered for swap.")
      return false
    elsif my_availability.request
      errors.add(:availability, "#{availability.user} is no longer available to swap for #{offer_request}.")
      return false
    elsif offer_request.user.unavailable?(self)
      errors.add(:availability, "#{offer_request.user} is no longer available to swap for #{self}.")
      return false
    end

    transaction do
      offer_availability = offer_request.user.availability_for!(self)
      update_attributes!(state: :received_offer, 
                         availability: offer_availability, 
                         fulfilling_swap: offer_request)
      offer_request.update_attributes!(state: :sent_offer, 
                                       availability: my_availability, 
                                       fulfilling_swap: self)
    end
  end
  
  def self.pending_requests(user_id)
    Request.where(user_id: user_id).select {|r| r.pending? }
  end
  
  def pending?
    received_offer? && start.future?
  end
  
  def future?
    start.future?
  end
  
  def accept_pending_swap
    if fulfilling_swap.nil?
      errors.add(:fulfilling_swap, "is missing.")
      return false
    elsif !received_offer?
      errors.add(:state, "should be received offer, but is #{state}")
      return false
    elsif availability.start != start
      errors.add(:availability, "must be for same shift")
    elsif fulfilling_swap.availability.user != self.user
      errors.add(:user, "Availability is for #{fulfilling_swap.availability.user}; should be for #{self.user}.")
    elsif fulfilling_swap.fulfilling_swap != self
        errors.add(:fulfilling_swap, "Swapped requests are not reciprocal #{self} => #{fulfilling_swap} => #{fulfilling_swap.fulfilling_swap}.")
    end

    update_attributes!(state: :fulfilled) # c.f. after_update
  end

  def decline_pending_swap
    if fulfilling_swap.nil?
      errors.add(:fulfilling_swap, "There is no swap offer pending.")
    elsif !received_offer?
      errors.add(:state, "Only received offers can be declined.")
      return false
    end

    update!(state: :seeking_offers) # c.f. after_update
  end
        
end
