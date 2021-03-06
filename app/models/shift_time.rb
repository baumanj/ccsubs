module ShiftTime

  def self.included(base)
    base.extend(ClassMethods)
  end

  def self.date_to_s(date)
    date_format = "%A, %B %-d"
    date_format += ", %Y" if date.year != Date.current.year
    date.strftime(date_format)
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
        location_as_int = User.locations[attributes[:location]]
        attributes.merge!(location: location_as_int) if location_as_int
      rescue TypeError
        # sometimes the first arg to a where or find isn't an attribute hash
        # if not, there's nothing to do here
      end
    end

    def find_by(attributes)
      fix_enum_attributes!(attributes)
      super
    end

    def find_or_create_by(attributes)
      fix_enum_attributes!(attributes)
      super
    end

    def find_or_create_by!(attributes)
      fix_enum_attributes!(attributes)
      super
    end

    def find_or_initialize_by(attributes)
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

  FIRST_SHIFT_START = { hour: 8, min: 0 }
  SHIFT_DURATIONS = [
    4.5.hours, # 0800–1230
    4.5.hours, # 1230–1700
    4.0.hours, # 1700–2100
    4.0.hours, # 2100–0100
  ]

  # The first shift always starts at 8am, even if Daylight Saving Time means
  # that it's not 8 hours since the beginning of that day
  def self.first_shift_start(date=Date.current)
    date.in_time_zone.change(FIRST_SHIFT_START)
  end

  def self.shift_ranges(date=Date.current)
    SHIFT_DURATIONS.reduce([]) do |ranges, duration|
      start = if ranges.empty?
        first_shift_start(date)
      else
        ranges.last.end
      end
      ranges + [start...(start + duration)]
    end
  end

  SHIFT_NAMES = shift_ranges.map do |tr|
    times = [tr.begin, tr.end]
    times.map {|t| t.strftime("%-l#{':%M' unless t.min.zero?}%P") }.join("-")
  end

  def self.next_shift(time=Time.current)
    current_shift = time_to_shift(time)
    if current_shift.nil?
      0 # before first shift
    else
      (current_shift + 1) % SHIFT_DURATIONS.length
    end
  end

  def self.next_date_and_shift(time=Time.current)
    shift = next_shift(time)
    date = if time < first_shift_start(time)
      time.to_date
    else
      shift_range = time_to_shift_ranges(time).find {|r| r.cover?(time) }
      shift_range.end.to_date
    end

    [date, shift]
  end

  def self.last_started_date_and_shift(time=Time.current)
    date = time_to_shift_date(time)
    shift = time_to_shift(time) || SHIFT_DURATIONS.each_index.to_a.last

    [date, shift]
  end

  def self.time_to_shift_date(time=Time.current)
    if time < first_shift_start(time)
      time.to_date.yesterday
    else
      time.to_date
    end
  end

  def self.time_to_shift_ranges(time=Time.current)
    date = time_to_shift_date(time)
    shift_ranges(date)
  end

  # Return shift index for the time or nil if not part of any shift
  def self.time_to_shift(time=Time.current)
    time_to_shift_ranges(time).index {|time_range| time_range.cover?(time) }
  end

  def shifttime_attrs
    slice(:shift, :date)
  end

  def self.next_shift_start(time=Time.current)
    first_shift_of_today_start = first_shift_start(time.to_date)
    if time < first_shift_of_today_start
      first_shift_of_today_start
    else
      time_to_shift_ranges(time).each_cons(2) do |curr, next_|
        return next_.begin if curr.cover?(time)
      end
      first_shift_start(time.to_date.tomorrow)
    end
  end

  def range
    if date && shift
      shift_index = self.class.shifts[shift]
      ShiftTime::shift_ranges(date)[shift_index]
    else
      nil...nil
    end
  end

  def start
    range.begin
  end

  def end
    range.end
  end

  def active?
    self.class.active.include?(self)
  end

  def to_s(with_location: true)
    s = "#{ShiftTime.date_to_s(date)}, #{shift}"
    if with_location && self.respond_to?(:location)
      if location == "Renton" && date < RENTON_OPENING_DATE
        s += " in Belltown*"
      else
        s += " in #{location}"
      end
    end
    s += " [#{id}]" if Rails.env.development?
    s
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
    if self.class.where.not(id: self.id).find_by(slice(:user, :date, :shift))
      errors.add(:shift, "can't be the same as your own existing #{self.class.to_s.humanize(capitalize: false)}")
    end
  end

  def shift_is_between_now_and_a_year_from_now
    if start.nil?
      errors.add(:start, "time must be specified.")
    elsif start < Time.current
      errors.add(:start, "time must be in the future. #{start} is in the past")
    elsif start.to_date > 1.year.since(Date.today)
      errors.add(:start, "time must be within a year.")
    end
  end

  LOCATION_CHANGE_DATE = Date.new(2020, 4, 1)
  RENTON_OPENING_DATE = Date.new(2021, 6, 1)
  LOCATION_BEFORE = User.locations.keys.first
  LOCATIONS_AFTER = User.locations.keys.reject {|l| l == LOCATION_BEFORE }

  def self.valid_locations_for(date)
    date = date.to_date
    if date < LOCATION_CHANGE_DATE
      [LOCATION_BEFORE]
    elsif date < RENTON_OPENING_DATE
      LOCATIONS_AFTER - ["Renton"]
    else
      LOCATIONS_AFTER
    end
  end

  def location_is_valid_for_date
    valid_locations = ShiftTime::valid_locations_for(date)
    if !valid_locations.include?(location)
      errors.add(:location, "must be #{valid_locations.join(" or ")}")
    elsif self.userless?
        # Ok (e.g., holiday requests)
    elsif location != user.location_for(date)
      errors.add(:location, "must match user's location for #{date}: #{user.location_for(date)}")
    end
  end

end

class ShiftTimeValidator < ActiveModel::Validator
  def validate(record)
    if record.new_record?
      record.no_schedule_conflicts
      record.shift_is_between_now_and_a_year_from_now
    end
    # ^ can these be for more than just new records?
  end
end