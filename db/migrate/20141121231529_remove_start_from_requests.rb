class RemoveStartFromRequests < ActiveRecord::Migration
  def change
    remove_column :requests, :start
  end
end
