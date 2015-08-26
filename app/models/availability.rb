class Availability < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  has_one :request
  
  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validate :shift_is_in_the_future
  validate :no_schedule_conflicts

  after_create do
    availability_user_open_requests = user.open_requests
    if availability_user_open_requests.any?
      Request.seeking_offers.where(date: self.date, shift: self.shift_to_i).each do |req|
        UserMailer.notify_matching_avilability(req, availability_user_open_requests).deliver
      end
    end
    # find the users with outstanding requests matching this and notify them
    # v2: only send a notification email if there have been new matching availabilities
    # added since the last time the user visited the site (or maybe 1/day)
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
end
