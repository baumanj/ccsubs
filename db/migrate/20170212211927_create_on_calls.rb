class CreateOnCalls < ActiveRecord::Migration
  def change
    create_table :on_calls do |t|
      t.date :date, null: false
      t.integer :shift, null: false
      t.references :user, index: true, foreign_key: true, null: false

      t.timestamps null: false
    end
  end
end
