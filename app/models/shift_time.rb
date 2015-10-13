module ShiftTime

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def where_shifttime(shifttime)
      self.where(shifttime.shifttime_attrs)
    end

    def find_by_shifttime(shifttime)
      self.find_by(shifttime.shifttime_attrs)
    end

    def find_by_shifttime!(shifttime)
      self.find_by!(shifttime.shifttime_attrs)
    end

    def fix_enum_attributes!(attributes)
      begin
        # Fix up enums: c.f. https://hackhands.com/ruby-on-enums-queries-and-rails-4-1/
        # shift_as_int = ShiftTime::SHIFT_NAMES.find(attributes[:shift])
        shift_as_int = shifts[attributes[:shift]]
        attributes.merge!(shift: shift_as_int) if shift_as_int
      rescue TypeError
        # sometimes the first arg to a where or find isn't an attribute hash
        # if not, there's nothing to do here
      end
    end

    def find_by(attributes)
      fix_enum_attributes!(attributes)
      super
    end

    def where(opts = :chain, *rest)
      fix_enum_attributes!(opts)
      super
    end

    def on_or_after(date_)
      where("#{table_name}.date >= ?", date_)
    end

    def after(date_or_time)
      date = date_or_time.to_date
      next_shift = ShiftTime::next_shift(date_or_time.to_time)
      where("#{table_name}.date > ? OR (#{table_name}.date = ? AND #{table_name}.shift >= ?)", date, date, next_shift)
    end

    def future
      after(Time.now)
    end

    def active_check
      fast = active.to_a.sort
      medium = self.select(&:active?).sort
      slow = self.select(&:active_slow?).sort
      puts fast == medium
      puts medium == slow
    end
  end
  
  SHIFT_NAMES = [ '8am-12:30pm', '12:30pm-5pm', '5pm-9pm', '9pm-1am' ]
  DATE_FORMAT = "%A, %B %e"

  def self.next_shift(time=Time.now)
    SHIFT_NAMES.index {|s| time < Time.parse(s.split("-").first) } || 0
  end

  def shifttime_attrs
    slice(:shift, :date)
  end

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
      Time.parse(shift.split('-').first, date)
    end
  end

  def active?
    self.class.active.include?(self)
  end

  def to_s
    s = "#{date.strftime(DATE_FORMAT)}, #{shift.delete('ampm')}"
    Rails.env.development? ? "#{s} [#{id}]" : s
  end

  def no_schedule_conflicts
    if self.class.find_by(slice(:user, :date, :shift))
      errors.add(:shift, "can't be the same as your own existing #{self.class.to_s.humanize(capitalize: false)}")
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