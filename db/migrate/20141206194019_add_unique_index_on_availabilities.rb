class AddUniqueIndexOnAvailabilities < ActiveRecord::Migration
  def change
    add_index :availabilities, [:user_id, :shift, :date], unique: true
  end
end
