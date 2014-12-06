class RenameFulfillingSubToAvailability < ActiveRecord::Migration
  def change
    rename_column :requests, :fulfilling_sub_id, :availability_id
  end
end
