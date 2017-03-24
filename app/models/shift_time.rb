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

    def relative(date_or_time, date_op, shift_op)
      date = date_or_time.to_date
      next_shift = ShiftTime::next_shift(date_or_time.to_time)
      where("#{table_name}.date #{date_op} ? OR " \
           "(#{table_name}.date = ? AND #{table_name}.shift #{shift_op} ?)",
            date, date, next_shift)
    end

    def after(date_or_time)
      relative(date_or_time, ">", ">=")
    end

    def before(date_or_time)
      relative(date_or_time, "<", "<")
    end

    def future
      after(Time.current)
    end

    def past
      before(Time.current)
    end

    def active_check
      fast = active.to_a.sort
      medium = self.select(&:active?).sort
      slow = self.select(&:active_slow?).sort
      puts fast == medium
      puts medium == slow
    end
  end
  
  SHIFT_OFFSETS = [
    8.hours   ...12.5.hours,
    12.5.hours...17.hours,
    17.hours  ...21.hours,
    21.hours  ...25.hours
  ]

  def self.time_range(offset_range, date)
    times = [offset_range.begin, offset_range.end].map {|off| date + off}
    Range.new(*times, offset_range.exclude_end?)
  end

  SHIFT_NAMES = SHIFT_OFFSETS.map do |offset_range|
    tr = ShiftTime.time_range(offset_range, Date.today)
    times = [tr.begin, tr.end]
    times.map {|t| t.strftime("%-l#{':%M' unless t.min.zero?}%P") }.join("-")
  end

  DATE_FORMAT = "%A, %B %e"

  def self.next_shift(time=Time.current)
    current_shift = time_to_shift(time)
    if current_shift.nil?
      0 # before first shift
    else
      (current_shift + 1) % SHIFT_OFFSETS.length
    end
  end

  def self.time_to_shift_time_ranges(time=Time.current)
    date = if time.seconds_since_midnight < (SHIFT_OFFSETS.last.end - 24.hours)
        time.to_date.yesterday
      else
        time.to_date
      end
    SHIFT_OFFSETS.map {|range| time_range(range, date) }
  end

  # Return shift index for the time or nil if not part of any shift
  def self.time_to_shift(time=Time.current)
    time_ranges = time_to_shift_time_ranges(time)
    time_ranges.index {|time_range| time_range.cover?(time) }
  end

  def shifttime_attrs
    slice(:shift, :date)
  end

  def self.shift_end(time=Time.current)
    time_ranges = time_to_shift_time_ranges(time)
    time_range = time_ranges.find {|time_range| time_range.cover?(time) }
    time_range.nil? ? time_ranges.first.begin : time_range.end
  end

  def start
    if date && shift
      date + SHIFT_OFFSETS[self.class.shifts[shift]].begin
    end
  end

  def end
    ShiftTime::shift_end(start) if start
  end

  def active?
    self.class.active.include?(self)
  end

  def to_s
    s = "#{date.strftime(DATE_FORMAT)}, #{shift}"
    Rails.env.development? ? "#{s} [#{id}]" : s
  end

  def to_ical(summary:, description:)
    require 'icalendar/tzinfo'

    cal = Icalendar::Calendar.new

    tzid = 'America/Los_Angeles'
    tz = TZInfo::Timezone.get tzid
    timezone = tz.ical_timezone self.start
    cal.add_timezone timezone

    cal.event do |e|
      e.dtstart = Icalendar::Values::DateTime.new self.start, 'tzid' => tzid
      e.dtend = Icalendar::Values::DateTime.new self.end, 'tzid' => tzid
      e.summary = summary
      e.description = description
      e.ip_class    = "PRIVATE"
    end

    cal.to_ical
  end

  def no_schedule_conflicts
    if self.class.find_by(slice(:user, :date, :shift))
      errors.add(:shift, "can't be the same as your own existing #{self.class.to_s.humanize(capitalize: false)}")
    end
  end

  def shift_is_between_now_and_a_year_from_now
    if start.nil?
      errors.add(:start, "time must be specified.")
    elsif start < Time.current
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