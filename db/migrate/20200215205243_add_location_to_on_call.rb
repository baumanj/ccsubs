class AddLocationToOnCall < ActiveRecord::Migration
  def change
    add_column :on_calls, :location, :integer, null: false, default: 0
  end
end
