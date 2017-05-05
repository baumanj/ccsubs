class OnCallReminder < ActiveRecord::Base
  Template = Struct.new(:mailer_method, :date_offset)

  TEMPLATES = [
    Template['remind_on_call_signup', -1.month],
    Template['remind_on_call_signup_again', -2.weeks],
  ]

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

  def self.send_reminders(today: Date.current, templates: self::TEMPLATES)
    date = today.next_month.beginning_of_month

    return if date < OnCall::FIRST_VALID_DATE

    sent_reminders = OnCallReminder.where(month: date.month, year: date.year)

    if sent_reminders.size < templates.size
      next_reminder = templates[sent_reminders.size]

      if today >= (date + next_reminder.date_offset)
        users = OnCall.users_to_nag(date.all_month)
        user_ids_string = YAML.dump(users.map(&:id))
        UserMailer.send(next_reminder.mailer_method, users, date).deliver_now if users.any?
        OnCallReminder.create!(month: date.month, year: date.year,
                               mailer_method: next_reminder.mailer_method,
                               user_ids: user_ids_string)
      end
    end
  end

end
