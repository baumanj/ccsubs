class AddFirstDayOfWeekPreferenceToUsers < ActiveRecord::Migration
  def change
    add_column :users, :first_day_of_week_preference, :integer, null: false, default: 0
  end
end
