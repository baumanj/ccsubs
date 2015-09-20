class Availability < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user
  has_one :request
  
  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validates_with ShiftTimeValidator
  validate do
    if free.nil?
      errors.add(:free, "Must be indicated 'Yes' or 'No'")
    end

    if free? && request != nil
      errors.add(:request, "Must be nil if free? is true")
    end

    if free? && user.requests.find {|r| r.start == self.start }
      errors.add(:shift, "can't be the same as your own existing request")
    end
  end

  after_create do
    # notify users with requests matching the availability this user just added
    if user.open_requests.any?
      UserMailer.active_user = user # For preview mode
      Request.seeking_offers.where_shifttime(self).each do |req|
        full_matches, half_matches = user.open_requests.partition {|r| req.user.available?(r) }
        if full_matches.any?
          # Just let the other user know; this user will be notified on their dashboard
          UserMailer.notify_match(req, full_matches).deliver
        else
          UserMailer.notify_partial_match(req, half_matches).deliver
        end
      end
    end
    # v2: only send a notification email if there have been new matching availabilities
    # added since the last time the user visited the site (or maybe 1/day)
  end

  before_destroy do
    if locked?
      errors.add(:availability, "Can not be deleted while tied to a pending offer")
      return false
    end
  end

  def busy?
    free == false # can't be nil; nil would imply unknown
  end

  def tentative?
    !request.nil? && !request.fulfilled?
  end

  def open?
    start.future? && free? && user.open_requests.any?
  end

  def locked?
    !request.nil?
  end

  # others are free for any of this user's requests
  def match?
    Request.where_shifttime(self).map(&:user).uniq.any? do |other|
      self.user.open_requests.any? {|r| other.availability_state_for(r) == :free }
    end
  end
end
