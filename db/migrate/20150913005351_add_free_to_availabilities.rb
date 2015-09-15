class AddFreeToAvailabilities < ActiveRecord::Migration
  def change
    add_column :availabilities, :free, :boolean, default: true, null: false
  end
end
