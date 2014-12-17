class AddUniqueIndexOnRequests < ActiveRecord::Migration
  def change
    add_index :requests, [:user_id, :shift, :date], unique: true
  end
end
