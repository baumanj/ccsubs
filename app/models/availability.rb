class Availability < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  has_one :request
  
  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validates_with ShiftTimeValidator

  attr_reader :create # for the checkbox tag

  def initialize(attributes = nil, options = {})
    @create = attributes.delete(:create) == "1" if attributes
    super
  end

  after_create do
    # notify users with requests matching the availability this user just added
    if user.open_requests.any?
      UserMailer.active_user = user # For preview mode
      Request.seeking_offers.where(date: self.date, shift: self.shift_to_i).each do |req|
        UserMailer.notify_matching_avilability(req, user.open_requests).deliver
      end
    end
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
