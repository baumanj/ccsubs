class AddLocationToRequest < ActiveRecord::Migration
  def change
    add_column :requests, :location, :integer, null: false, default: 0
  end
end
