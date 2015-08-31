class Availability < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  has_one :request
  
  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validates_with ShiftTimeValidator

  after_create do
    if user.open_requests.any?
      Request.seeking_offers.where(date: self.date, shift: self.shift_to_i).each do |req|
        mailer.notify_matching_avilability(req, user.open_requests).deliver
      end
    end
    # find the users with outstanding requests matching this and notify them
    # v2: only send a notification email if there have been new matching availabilities
    # added since the last time the user visited the site (or maybe 1/day)
  end

  def tentative?
    request && !request.fulfilled?
  end

  def locked?
    request != nil
  end
end
