class Availability < ActiveRecord::Base
  include ShiftTime

  belongs_to :user
  has_one :request
  
  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validate :shift_is_in_the_future

  def matching_requests
    Request.where(fulfilled: false).where(start: self.start).order(:id)
  end

  def shift_is_in_the_future
    if start && start < DateTime.now
      errors.add(:start, "time must be in the future")
    end
  end

end
