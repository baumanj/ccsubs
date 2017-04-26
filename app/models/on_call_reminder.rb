class OnCallReminder < ActiveRecord::Base
  Template = Struct.new(:email, :date_offset)

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

  def self.send_reminders(today = Date.current)
    [today, today.next_month].map(&:beginning_of_month).each do |date|
      next if date < OnCall::FIRST_VALID_DATE

      sent_reminders = OnCallReminder.where(month: date.month, year: date.year)

      if sent_reminders.size < TEMPLATES.size
        next_reminder = TEMPLATES[sent_reminders.size]

        if today >= (date + next_reminder.date_offset)
          users = OnCall.users_to_nag(date.all_month)
          user_ids_string = YAML.dump(users.map(&:id))
          UserMailer.send(next_reminder.email, users, date).deliver_now
          OnCallReminder.create!(month: date.month, year: date.year, user_ids: user_ids_string)
        end
      end
    end
  end

end
