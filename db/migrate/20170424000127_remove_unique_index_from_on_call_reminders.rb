class RemoveUniqueIndexFromOnCallReminders < ActiveRecord::Migration
  def change
    remove_index :on_call_reminders, column: [:month, :year]
  end
end
