class RemoveNameIndexFromUser < ActiveRecord::Migration
  def change
  	remove_index :users, column: [:name]
  end
end
