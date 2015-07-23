class Request < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }
  BRIEF_LEN = 140

  belongs_to :user
  belongs_to :fulfilling_swap, class_name: "Request"
  belongs_to :availability

  validates :user, presence: true
  validates :shift, presence: true
  validate :shift_is_between_now_and_a_year_from_now, on: :create
  validate :request_is_unique
  
  before_destroy do
    if !seeking_offers?
      errors.add(:state, "cannot be #{state}")
    elsif !future?
      errors.add(:start, "must be in the future")
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

  def brief_text
    if text.length <= BRIEF_LEN
      text
    else
      text[0, BRIEF_LEN] + "…"
    end
  end

  def shift_is_between_now_and_a_year_from_now
    if start.nil?
      errors.add(:start, "time must be specified.")
    elsif start < DateTime.now
      errors.add(:start, "time must be in the future.")
    elsif start > 1.year.from_now
      errors.add(:start, "time must be within a year.")
    end
  end
  
  def request_is_unique
    r = Request.find_by(user: user, date: date, shift: shift_to_i)
    if r && r != self
      errors.add(:request, "must be unique. You already have one for #{self}")
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
      users = Availability.where(date: date, shift: shift_to_i)
        .reject {|a| a.request }.map(&:user)
      requests = users.map(&:open_requests)
      users.zip(requests)
    end
  end

  def open?
    seeking_offers? && start.future?
  end
    
  def fulfilling_user
    (availability || fulfilling_swap).user if fulfilled?
  end

  def fulfill_by_sub(subber)
    if !subber.available?(self)
      errors.add(:availability, "#{subber} is not available to swap for #{self}.")
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
    elsif !offer_request.user.available?(self)
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

    transaction do
      availability.destroy!
      fulfilling_swap.availability.destroy!
      update_attributes!(state: :fulfilled, availability: nil)
      fulfilling_swap.update_attributes!(state: :fulfilled, availability: nil)
    end
  end

  def decline_pending_swap
    offer_request = fulfilling_swap
    offer_availability = availability
    my_availability = offer_request.availability

    if offer_request.nil?
      errors.add(:fulfilling_swap, "There is no swap offer pending.")
    elsif !received_offer?
      errors.add(:state, "Only received offers can be declined.")
      return false
    end
    
    transaction do
      [self, offer_request].each do |r|
        r.update_attributes!(state: :seeking_offers, availability: nil, 
                             fulfilling_swap: nil)
      end
      [my_availability, offer_availability].each do |a|
        a.destroy! if a.implicitly_created?
      end
    end
  end
        
end
