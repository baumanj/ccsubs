class Request < ActiveRecord::Base
  BRIEF_LEN = 140

  belongs_to :user
  belongs_to :fulfilling_user, class_name: "User"
  validates :user, presence: true
  validates :shift, presence: true
  validate :shift_is_between_now_and_a_year_from_now, on: :create

  DATE_FORMAT = "%A, %B %e"
  enum shift: [ :'8-12:30', :'12:30-5', :'5-9', :'9-1' ]

  def brief_text
    if text.length <= BRIEF_LEN
      text
    else
      text[0, BRIEF_LEN] + "…"
    end
  end

  def start
    if date && shift
      h, m = shift.split("-").first.split(":").map(&:to_i)
      m = 0 if m.nil?
      date + h.hours + m.minutes
    end
  end

  def time_string
    "#{date.strftime(DATE_FORMAT)}, #{shift}"
  end
  
  def swapped_shift_string
    shift_str, _ = Request.shifts.find do |key, val|
      swapped_shift.strftime("%l").strip == key.split("-").first.split(":").first
    end
    "#{swapped_shift..date.strftime(DATE_FORMAT)}, #{shift_str}"
  end

  def shift_is_between_now_and_a_year_from_now
    if start && start < DateTime.now
      errors.add(:start, "time must be in the future")
    end
  end

  def shift_is_within_a_year
    if start && start > 1.year.from_now
      errors.add(:start, "time must be within a year")
    end
  end
  
  def swap_candidates
    availabilities = Availability.where(start: self.start)
    requests = availabilities.flat_map do |availability|
      open_reqs = availability.user.requests.select do |req|
        !req.fulfilled? && req.start.future?
      end
    end
  end

  def pending_offer?
    fulfilling_user && !fulfilled?
  end

  def editable?
    !fulfilled? && !pending_offer?
  end
end
