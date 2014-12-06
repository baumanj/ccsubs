class Request < ActiveRecord::Base
  include ShiftTime

  BRIEF_LEN = 140

  belongs_to :user
#  belongs_to :fulfilling_user, class_name: "User"
  belongs_to :fulfilling_swap, class_name: "Request"
  belongs_to :fulfilling_sub, class_name: "Availability"

  validates :user, presence: true
  validates :shift, presence: true
  validate :shift_is_between_now_and_a_year_from_now, on: :create
  validate :sub_availability_matches_request

  enum shift: ShiftTime::SHIFT_NAMES
  enum state: [ :seeking_offers, :received_offer, :sent_offer, :fulfilled ]

  def self.all_seeking_offers
    Request.seeking_offers.where("date >= ?", Date.today)
      .order(:date, :shift).select {|r| r.start > Time.now }
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
      errors.add(:start, "time must be in the future")
    elsif start > 1.year.from_now
      errors.add(:start, "time must be within a year")
    end
  end
  
  # Find the availabilities that aren't attached to requests and which belong
  # to users with open requests
  def swap_candidates
    availabilities = Availability.where(date: self.date, shift: self.shift)
    requests = availabilities.flat_map do |availability|
      availability.user.requests.select {|req| req.open? }
    end
  end

  def open?
    seeking_offers? && start.future?
  end
    
  def fulfilling_user
    (fulfilling_swap || fulfilling_sub).user
  end
  
  def sub_availability_matches_request
    if fulfilling_sub && fulfilling_sub.start != start
      errors.add(:fulfilling_sub, "sub must be for same shift")
    end
  end

  def fulfill_by_sub(user)
    transaction do
      availability = user.availabilities.find_by(date: date, shift: shift)
      if availability.nil?
        # If the user offering sub hasn't created that availability already,
        # just make it. We'll take their word for it.
        availability = Availability.create!(user: user, shift: shift, date: date)
      end
      update_attributes(fulfilling_sub: availability, state: :fulfilled)
    end
  end
  
end
