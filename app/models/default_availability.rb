class DefaultAvailability < ActiveRecord::Base
  belongs_to :user

  enum shift: ShiftTime::SHIFT_NAMES
  enum cwday: { Monday: 1, Tuesday: 2, Wednesday: 3, Thursday: 4, Friday: 5, Saturday: 6, Sunday: 7 }

  validates :user, presence: true
  validates :shift, inclusion: { in: self.shifts.keys }
  validates :cwday, inclusion: { in: self.cwdays.keys }

  def self.find_for_edit(user)
    da_relation = user.default_availabilities
    self.cwdays.values.product(self.shifts.values).map do |cwday, shift|
      da_relation.find_or_initialize_by(cwday: cwday, shift: shift)
    end
  end

  def self.find_or_initialize_by_shifttime(shifttime)
    self.find_or_initialize_by(cwday: shifttime.date.cwday, shift: shifttime.class.shifts[shifttime.shift])
  end

  def to_s
    s = "#{cwday}, #{shift}"
    Rails.env.development? ? "#{s} [#{id}]" : s
  end
end
