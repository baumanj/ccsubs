class RemoveEndFromRequests < ActiveRecord::Migration
  def change
    remove_column :requests, :end
  end
end
