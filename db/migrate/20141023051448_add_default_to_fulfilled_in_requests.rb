class AddDefaultToFulfilledInRequests < ActiveRecord::Migration
  def change
    change_column :requests, :fulfilled, :boolean, default: false
  end
end
