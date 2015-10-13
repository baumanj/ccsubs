module ShiftTime
  
  SHIFT_NAMES = [ :'8-12:30', :'12:30-5', :'5-9', :'9-1' ]
  DATE_FORMAT = "%A, %B %e"
  
  def self.shift_end(time=Time.now)
    ranges = [
      (Time.zone.parse('1am')...Time.zone.parse('8am')),
      (Time.zone.parse('8am')...Time.zone.parse('12:30pm')),
      (Time.zone.parse('12:30pm')...Time.zone.parse('5pm')),
      (Time.zone.parse('5pm')...Time.zone.parse('9pm'))
    ]
    ranges.each {|r| return r.end if r.cover?(time) }
    return Date.tomorrow + 1.hour
  end

  def start
    if date && shift
      case shift
      when '8-12:30'
        date + 8.hours
      when'12:30-5'
        date + 12.hours + 30.minutes
      when '5-9'
        date + (12 + 5).hours
      when '9-1'
        date + (12 + 9).hours
      end
    end
  end

  def to_s
    "#{date.strftime(DATE_FORMAT)}, #{shift}"
  end
  
  # Enums kinda suck, we need their integer value in query contexts
  # https://hackhands.com/ruby-on-enums-queries-and-rails-4-1/
  def shift_to_i
    self.class.shifts[shift]
  end

  def no_schedule_conflicts
    if self.class.find_by(user: user, date: date, shift: shift_to_i)
      errors.add(:shift, "can't be the same as your own existing #{self.class.to_s.humanize(capitalize: false)}")
    elsif user.requests.find_by(date: date, shift: shift_to_i)
      errors.add(:shift, "can't be the same as your own existing request")
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
end

class ShiftTimeValidator < ActiveModel::Validator
  def validate(record)
      if record.new_record?
        record.no_schedule_conflicts
        record.shift_is_between_now_and_a_year_from_now
      end
  end
end