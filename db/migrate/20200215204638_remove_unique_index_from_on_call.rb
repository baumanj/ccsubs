class RemoveUniqueIndexFromOnCall < ActiveRecord::Migration
  def change
  	remove_index :on_calls, column: [:shift, :date]
  end
end
