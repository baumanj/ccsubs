class RemoveDayAndEventTypeDefaultsForSignupReminderRedux < ActiveRecord::Migration
  def change
    change_column_default :signup_reminders, :day, nil
    change_column_default :signup_reminders, :event_type, nil
  end
end
