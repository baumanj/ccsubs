class Unavailability < ActiveRecord::Base
  include ShiftTime
  default_scope { order(:date, :shift) }

  belongs_to :user

  enum shift: ShiftTime::SHIFT_NAMES

  validates :user, presence: true
  validates_with ShiftTimeValidator
end
