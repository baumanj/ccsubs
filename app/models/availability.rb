class Availability < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  has_one :request
  
  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validate :shift_is_in_the_future
  validate :no_schedule_conflicts

  def matching_requests
    Request.where(fulfilled: false).where(start: self.start).order(:id)
  end

  def shift_is_in_the_future
    if start && start < DateTime.now
      errors.add(:start, "time must be in the future")
    end
  end

  def no_schedule_conflicts
    if user.availabilities.find_by(date: date, shift: shift_to_i)
      errors.add(:start, "can't be duplicated")
    elsif user.requests.find_by(date: date, shift: shift_to_i)
      errors.add(:availability, "can't conflict with user's own request")
    end
  end
  
  def tentative?
    request && request.pending?
  end
  
  def request
    r = read_attribute(:request)
    r if r && r.future?
  end
end
