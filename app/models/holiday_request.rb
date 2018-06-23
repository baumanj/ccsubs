class HolidayRequest < Request
  SHIFT_SLOTS = 5

  default_scope { where(type: 'HolidayRequest') }
  scope :active, -> { future.seeking_offers }

  before_save do
    case state
    when 'seeking_offers', 'fulfilled' # yay, nothing to do
    else
      raise NotImplementedError
    end
  end

  def self.create_any_not_present
    (Holiday::NAMES - [Holiday::INDEPENDENCE_DAY]).each do |name|
      date = Holiday.next_date(name)
      next if date > 1.year.from_now # E.g., next MLK day on 2018-1-16
      shifts = case name
        when Holiday::CHRISTMAS_EVE
          self.shifts.values.last 2
        else
          self.shifts.values
        end

      shifts.each do |shift|
        (1..SHIFT_SLOTS).each do |slot|
          self.find_or_create_by!(user_id: -slot, date: date, shift: shift)
        end
      end
    end
  end

  def userless?
    true
  end

  def user
    nil
  end

  def to_s
    "Holiday Shift: #{super.to_s}"
  end

  def inspect
    if (seeking_offers? != availability.nil?) || (availability && availability.start != start)
      # Something's wrong!
      availability_str = ", !!!AVAILABILITY!!!: #{availability.inspect}!!!"
    elsif availability
      availability_str = ", availability: #{availability.user.name}[#{availability.user.id}]'s availability[#{availability.id || 'new'}]"
    end
    "#<HolidayRequest id: #{self.id}, "\
      "date: #{date}, shift[#{self.class.shifts[shift]}]: #{shift}, "\
      "state[#{self.class.states[state]}]: #{state}#{availability_str}>"
  end

end
