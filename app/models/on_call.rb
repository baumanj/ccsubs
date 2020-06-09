class OnCall < ActiveRecord::Base
  include ShiftTime

  belongs_to :user

  FIRST_VALID_DATE = Date.new(2017, 6, 1)
  enum shift: ShiftTime::SHIFT_NAMES
  enum location: User.locations

  validates :user, presence: true
  validates :shift, presence: true
  validates :date, presence: true
  validates :date, uniqueness: { scope: [:shift, :location] }
  validates :location, presence: true

  validate do
    shift_is_between_now_and_a_year_from_now
    location_is_valid_for_date

    if user.requests.find_by_shifttime(self)
      errors.add(:shift, "can't be the same as your request for coverage")
    end

    if self.date < FIRST_VALID_DATE
      errors.add(:date, "can't be before #{OnCall::FIRST_VALID_DATE.strftime("%B %-d")}")
    end

    if OnCall.where.not(id: self.id).exists?(user: user, date: date.all_month)
      errors.add(:date, "can't be the same month as existing signup")
    end
  end

  # If you're on call, you can't be available to sub
  before_create do
    availability = user.availabilities.find_or_initialize_by(shifttime_attrs)
    self.prior_availability = availability.new_record? ? nil : availability.free
    availability.update!(free: false, implicitly_created: availability.new_record?)
    true # to avoid https://apidock.com/rails/ActiveRecord/RecordNotSaved
  end

  after_destroy do
    availability = user.availabilities.find_by(shifttime_attrs)
    if availability
      if availability.implicitly_created? || self.prior_availability.nil?
        availability.destroy!
      else
        availability.update!(free: self.prior_availability)
      end
    end
  end

  def userless?
    false
  end

  def self.users_to_nag(date_range)
    on_calls = OnCall.where(date: date_range)
    if on_calls.count == date_range.count * OnCall.shifts.size
      return []
    else
      types = User.volunteer_types.fetch_values('Regular Shift', 'Alternating')
      return User.where(volunteer_type: types, disabled: false) - on_calls.map(&:user)
    end
  end

  def self.destroy_for_disabled_users
    destroyed = OnCall.future.joins(:user).where(users: {disabled: true}).destroy_all
    if destroyed.any?
      message = "Destroyed #{destroyed.count} on calls of disabled users #{destroyed.map(&:user).map(&:name).uniq.join(', ')}"
      puts message
      UserMailer.alert(message).deliver_now
    end
  end
end
