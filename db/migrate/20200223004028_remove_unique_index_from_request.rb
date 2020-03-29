class RemoveUniqueIndexFromRequest < ActiveRecord::Migration
  def change
  	remove_index :requests, column: [:user_id, :shift, :date]
  end
end
