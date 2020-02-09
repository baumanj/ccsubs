class AddLocationToUser < ActiveRecord::Migration
  def change
    add_column :users, :location, :integer, null: false, default: 0
  end
end
