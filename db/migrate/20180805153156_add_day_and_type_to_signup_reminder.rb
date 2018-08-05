class AddDayAndTypeToSignupReminder < ActiveRecord::Migration
  def change
    add_column :signup_reminders, :day, :integer, null: false, default: 1
    add_column :signup_reminders, :type, :integer, null: false, default: 0
  end
end
