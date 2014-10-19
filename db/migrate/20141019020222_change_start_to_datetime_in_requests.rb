class ChangeStartToDatetimeInRequests < ActiveRecord::Migration
  def change
    remove_column :requests, :start
    add_column :requests, :start, :datetime
  end
end
