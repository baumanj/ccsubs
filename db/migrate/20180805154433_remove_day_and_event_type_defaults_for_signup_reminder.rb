class RemoveDayAndEventTypeDefaultsForSignupReminder < ActiveRecord::Migration
  def change
    change_column :signup_reminders, :day, :integer, null: false
    change_column :signup_reminders, :event_type, :integer, null: false
  end
end
