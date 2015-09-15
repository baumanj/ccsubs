class ChangeAvailabilityFreeDefaultToNilRedux < ActiveRecord::Migration
  def change
    change_column_default :availabilities, :free, nil
  end
end
