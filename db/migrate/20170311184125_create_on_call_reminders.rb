class CreateOnCallReminders < ActiveRecord::Migration
  def change
    create_table :on_call_reminders do |t|
      t.integer :month, null: false
      t.integer :year, null: false
      t.text :user_ids, null: false

      t.timestamps null: false
    end
    add_index :on_call_reminders, [:month, :year], unique: true
  end
end
