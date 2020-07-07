class HolidayRequest < Request
  SHIFT_SLOTS = { "Belltown" => 6, "Renton" => 4 }
  FIRST_VALID_DATE = Date.new(2018, 9, 3)

  default_scope { where(type: 'HolidayRequest') }
  scope :active, -> { future.seeking_offers }

  before_save do
    case state
    when 'seeking_offers', 'fulfilled'
      # Safe naviation needed for FactoryBot linting
      if fulfilling_user&.volunteer_type == 'Sub Only'
        UserMailer.alert_sub_only_holiday(self).deliver_now
      end
      true
    else
      raise NotImplementedError
    end
  end

  def self.create_any_not_present
    Holiday::dates_in_coming_year.each do |date|
      shifts = case Holiday::name(date)
        when Holiday::CHRISTMAS_EVE, Holiday::NEW_YEARS_EVE
          self.shifts.values.last 2
        else
          self.shifts.values
        end

      shifts.each do |shift|
        valid_locations = ShiftTime.valid_locations_for(date)
        valid_locations.each do |location|
          (1..SHIFT_SLOTS[location]).each do |slot|
            self.find_or_create_by!(user_id: -slot, date: date, shift: shift, location: location)
          end
        end
      end
    end
  end

  def self.reset_for_disabled_users
    reqs_to_reset = self.future.fulfilled.select {|req| req.fulfilling_user.disabled }
    reqs_to_reset_fulfilling_users = reqs_to_reset.map(&:fulfilling_user).map(&:name).uniq
    reqs_to_reset.each do |req|
      req.availability_id = nil
      req.state = self.states["seeking_offers"]
      req.save(validate: false)
    end
    if reqs_to_reset.any?
      message = "Reset #{reqs_to_reset.count} holiday requests fulfilled by disabled users #{reqs_to_reset_fulfilling_users.join(', ')}"
      puts message
      UserMailer.alert(message).deliver_now
    end
  end

  def self.users_to_nag(date)
    if HolidayRequest.where(date: date).seeking_offers.any?
      types = User.volunteer_types.fetch_values('Regular Shift', 'Alternating')
      users_who_should_do_holidays = User.where(volunteer_type: types, disabled: false)
      users_who_did_a_holiday = HolidayRequest.after(1.year.ago(date)).fulfilled.map(&:fulfilling_user)
      users_who_should_do_holidays - users_who_did_a_holiday
    else
      []
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
    "#<HolidayRequest id: #{self.id}, user_id: #{user_id}, "\
      "date: #{date}, shift[#{self.class.shifts[shift]}]: #{shift}, "\
      "location[#{self.class.locations[location]}]: #{location}, "\
      "state[#{self.class.states[state]}]: #{state}#{availability_str}>"
  end

end
