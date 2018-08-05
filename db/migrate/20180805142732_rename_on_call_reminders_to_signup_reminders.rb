class RenameOnCallRemindersToSignupReminders < ActiveRecord::Migration
  def change
  	rename_table :on_call_reminders, :signup_reminders
  end
end
