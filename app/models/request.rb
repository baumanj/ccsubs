class Request < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }
  BRIEF_LEN = 140

  belongs_to :user
#  belongs_to :fulfilling_user, class_name: "User"
  belongs_to :fulfilling_swap, class_name: "Request"
  belongs_to :availability # The availability that is fulfilling this request

  validates :user, presence: true
  validates :shift, presence: true
  validate :shift_is_between_now_and_a_year_from_now, on: :create
  validate :availability_matches_request

  enum shift: ShiftTime::SHIFT_NAMES
  enum state: [ :seeking_offers, :received_offer, :sent_offer, :fulfilled ]

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

  def swapped_shift_string
    shift_str, _ = Request.shifts.find do |key, val|
      swapped_shift.strftime("%l").strip == key.split("-").first.split(":").first
    end
    "#{swapped_shift..date.strftime(DATE_FORMAT)}, #{shift_str}"
  end

  def shift_is_between_now_and_a_year_from_now
    if start < DateTime.now
      errors.add(:start, "time must be in the future.")
    elsif start > 1.year.from_now
      errors.add(:start, "time must be within a year.")
    end
  end
  
  # Find the availabilities that aren't attached to requests and which belong
  # to users with open requests
  # We want the list of requests that the other users have, paired with their availability for THIS request
  def swap_candidates
    availabilities = Availability.where(date: date, shift: shift_to_i).reject {|a| a.request }
    requests = availabilities.map do |availability|
      availability.user.requests.select {|req| req.open? }
    end
    availabilities.zip(requests)
  end

  def open?
    seeking_offers? && start.future?
  end
    
  def fulfilling_user
    availability.user if fulfilled?
  end
  
  def availability_matches_request
    return unless fulfilled?
    
    if availability.start != start
      errors.add(:availability, "sub must be for same shift")
    end
    
    if fulfilling_swap
      if availability.fulfilling_swap.user != self.user
        errors.add(:user, "Availability is for #{availability.fulfilling_swap.user}; should be for #{self.user}.")
      end
      
      if fulfilling_swap.fulfilling_swap != self
        errors.add(:fulfilling_swap, "Swapped requests are not reciprocal #{self} => #{fulfilling_swap} => #{fulfilling_swap.fulfilling_swap}.")
      end
    end
  end

  def fulfill_by_sub(subber)
    if !subber.available?(self)
      errors.add(:availability, "#{subber} is no longer available to swap for #{self}.")
      return false
    end
    transaction do
      sub_availability = subber.availability_for!(self)
      update_attributes!(fulfilling_sub: sub_availability, state: :fulfilled)
    end
  end
  
  # my_availability is the self.user's availability to cover offer_request
  # self.availability will be set to the availibilty for covering this request
  def set_pending_swap(offer_request, my_availability)
    if !offer_request.open?
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
