class ChangeAvailabilityFreeDefaultToNil < ActiveRecord::Migration
  def change
    change_column :availabilities, :free, :boolean, default: nil, null: false
  end
end
