class Message < ActiveRecord::Base
  include ShiftTime
  enum shift: ShiftTime::SHIFT_NAMES
  validates :date, presence: true
  validates :shift, presence: true

  validate do
    if start && ShiftTime.shift_end(start).past?
      errors.add(:shift, "must not have already ended")
    end
  end

  BOILERPLATE =<<-EOM
If you’re able to help us out, please call directly into the phone room at 206-461-3210 x1.
Please do not email back! (The CCsubs email is not connected to phone room staff emails.)
  EOM

  def subject
    "Emergency help needed #{self}"
  end

  def body_with_boilerplate
    [body.strip, BOILERPLATE].join("\n\n").strip
  end
end
