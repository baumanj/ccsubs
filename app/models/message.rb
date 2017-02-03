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

  def recipients
    enabled_users = User.where(disabled: false)
    enabled_user_ids = enabled_users.pluck(:id)
    availabilities = Availability.where_shifttime(self)
                                 .where(user_id: enabled_user_ids)
                                 .index_by(&:user_id)
    default_availabilities = DefaultAvailability.where_shifttime(self)
                                                .where(user_id: enabled_user_ids)
                                                .index_by(&:user_id)
    requests = Request.where_shifttime(self)
    requesting_users = requests.map(&:user)
    fulfilling_users = requests.map(&:fulfilling_user)

    enabled_users.reject do |user|
      free, default_free = [availabilities, default_availabilities].map do |a|
        a.has_key?(user.id) ? a[user.id].free : nil
      end
      requesting = requesting_users.include?(user)
      fulfilling = fulfilling_users.include?(user)
      free == false  || (free.nil? && default_free == false) || requesting || fulfilling
      # TODO add users for whom this is their default shift
    end
  end

end
