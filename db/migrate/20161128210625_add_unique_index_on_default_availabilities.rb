class AddUniqueIndexOnDefaultAvailabilities < ActiveRecord::Migration
  def change
    add_index :default_availabilities, [:user_id, :shift, :cwday], unique: true
  end
end
