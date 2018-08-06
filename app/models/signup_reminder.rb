class SignupReminder < ActiveRecord::Base
  Template = Struct.new(:mailer_method, :date_offset)

  ON_CALL_TEMPLATES = [
    Template['remind_on_call_signup', -1.month],
    Template['remind_on_call_signup_again', -2.weeks],
  ]

  HOLIDAY_TEMPLATES = [
    Template['remind_holiday_signup', -1.month],
    Template['remind_holiday_signup_again', -2.weeks],
  ]

  enum event_type: [ :on_call, :holiday ]
  validates :day, presence: true
  validates :month, presence: true
  validates :year, presence: true
  validates :user_ids, presence: true
  validates :mailer_method, presence: true
  validates :event_type, presence: true

  validate do
    begin
      if Date.new(year, month) < OnCall::FIRST_VALID_DATE
        errors.add(:month, "must be not be before #{OnCall::FIRST_VALID_DATE}")
      end
    rescue ArgumentError
      errors.add(:date, "must be valid")
    end
  end

  def users
    User.find(YAML.load(user_ids))
  end

  class << self

    def send_for_on_call(today: Date.current, templates: self::ON_CALL_TEMPLATES)
      event_start = today.next_month.beginning_of_month
      return if event_start < OnCall::FIRST_VALID_DATE
      users = OnCall.users_to_nag(event_start.all_month)
      send_reminders(today, :on_call, event_start, templates, users)
    end

    def send_for_holiday(today: Date.current, templates: self::HOLIDAY_TEMPLATES)
      holiday_date = Holiday.next_after(today)
      users = HolidayRequest.users_to_nag(holiday_date)
      send_reminders(today, :holiday, holiday_date, templates, users)
    end

    private

    def send_reminders(today, event_type, event_start, templates, users)
      sent_reminders = SignupReminder.where(month: event_start.month,
                                            year:  event_start.year,
                                            day:   event_start.day,
                                            event_type: self.event_types[event_type])

      if sent_reminders.size < templates.size
        next_reminder = templates[sent_reminders.size]

        if today >= (event_start + next_reminder.date_offset)
          user_ids_string = YAML.dump(users.map(&:id))
          UserMailer.send(next_reminder.mailer_method, users, event_start).deliver_now if users.any?
          SignupReminder.create!(day:   event_start.day,
                                 month: event_start.month,
                                 year:  event_start.year,
                                 event_type: event_type,
                                 mailer_method: next_reminder.mailer_method,
                                 user_ids: user_ids_string)
        end
      end
    end
  end

end
