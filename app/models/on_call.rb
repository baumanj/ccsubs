class OnCall < ActiveRecord::Base
  include ShiftTime

  belongs_to :user

  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validates :shift, presence: true
  validates :date, presence: true
  validates :date, uniqueness: { scope: :shift }

  validate do
    shift_is_between_now_and_a_year_from_now
    if user.requests.find_by_shifttime(self)
      errors.add(:shift, "can't be the same as your request for coverage")
    end
  end

  # If you're on call, you can't be available to sub
  before_create do
    availability = user.availabilities.find_or_initialize_by(shifttime_attrs)
    prior_availability = availability.new_record? ? nil : availability.free
    availability.update(free: false, implicitly_created: availability.new_record?)
  end

  before_destroy do
    unless prior_availability.nil?
      availability = user.availabilities.find_by(shifttime_attrs)
      if availability.implicitly_created?
        availability.destroy!
      else
        availability.update(free: prior_availability)
      end
    end
  end

  def self.users_to_nag(date_range)
    on_calls = OnCall.where(date: date_range)
    if on_calls.count == date_range.count * OnCall.shifts.size
      return []
    else
      return User.where(volunteer_type: "Regular Shift") - on_calls.map(&:user)
    end
  end

end