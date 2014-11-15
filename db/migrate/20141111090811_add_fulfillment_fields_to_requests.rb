class AddFulfillmentFieldsToRequests < ActiveRecord::Migration
  def change
    add_column :requests, :fulfilling_user_id, :integer
    add_column :requests, :swapped_shift, :datetime
  end
end
