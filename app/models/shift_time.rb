module ShiftTime

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def where_shifttime(shift)
      self.where(date: shift.date, shift: shift.shift_to_i)
    end

    def find_by_shifttime(shift)
      self.find_by(date: shift.date, shift: shift.shift_to_i)
    end
  end
  
  SHIFT_NAMES = [ '8-12:30', '12:30-5', '5-9', '9-1' ]
  DATE_FORMAT = "%A, %B %e"
  
  def self.fix_attrs_for_find!(attrs)
    attrs.merge!(shift: ShiftTime::SHIFT_NAMES.find_index(attrs[:shift] || attrs[:shift]))
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
    s = "#{date.strftime(DATE_FORMAT)}, #{shift}"
    Rails.env.development? ? "#{s} [#{id}]" : s
  end
  
  # Enums kinda suck, we need their integer value in query contexts
  # https://hackhands.com/ruby-on-enums-queries-and-rails-4-1/
  def shift_to_i
    self.class.shifts[shift]
  end

  def no_schedule_conflicts
    if self.class.find_by(user: user, date: date, shift: shift_to_i)
      errors.add(:shift, "can't be the same as your own existing #{self.class.name.downcase}")
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