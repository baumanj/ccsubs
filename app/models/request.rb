class Request < ActiveRecord::Base
  SHIFTS = { '8-12:30' => 8, '12:30-5' => 12, '5-9' => 17, '9-1' => 21 }
  SHIFT_STRINGS = SHIFTS.invert
  BRIEF_LEN = 140

  belongs_to :user
  belongs_to :fulfilling_user, class_name: "User"
  validates :start, presence: true
  validates :shift, inclusion: { in: SHIFTS.values, message: "must be selected" }
  validates :user, presence: true
  validate :shift_is_in_the_future

  Time::DATE_FORMATS[:shift_date] = "%A, %B %e"

  def shift
    start.hour if start and SHIFTS.values.include?(start.hour)
  end

  def shift=(val)
    self.start = start - start.hour.hours + val.to_i.hours unless start.nil?
  end

  def brief_text
    if text.length <= BRIEF_LEN
      text
    else
      text[0, BRIEF_LEN] + "…"
    end
  end

  def time_string
    "#{start.to_s(:shift_date)}, #{SHIFT_STRINGS[shift]}"
  end
  
  def swapped_shift_string
    "#{swapped_shift.to_s(:shift_date)}, #{SHIFT_STRINGS[shift]}"
  end

  def shift_is_in_the_future
    if start && start < DateTime.now
      errors.add(:start, "time must be in the future")
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

end
