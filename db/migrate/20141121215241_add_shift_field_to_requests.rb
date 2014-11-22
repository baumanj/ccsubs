class AddShiftFieldToRequests < ActiveRecord::Migration
  def change
    add_column :requests, :shift, :integer
    add_column :requests, :date, :date
  end
end
