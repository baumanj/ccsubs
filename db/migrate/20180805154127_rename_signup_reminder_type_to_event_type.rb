class RenameSignupReminderTypeToEventType < ActiveRecord::Migration
  def change
  	rename_column :signup_reminders, :type, :event_type
  end
end
