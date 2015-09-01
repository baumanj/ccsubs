class CreateUnavailabilities < ActiveRecord::Migration
  def change
    create_table :unavailabilities do |t|
      t.references :user, index: true, null: false
      t.integer :shift, null: false
      t.date :date, null: false

      t.timestamps
    end

    add_index :unavailabilities, [:user_id, :shift, :date], unique: true
  end
end
