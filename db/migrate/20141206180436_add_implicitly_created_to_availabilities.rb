class AddImplicitlyCreatedToAvailabilities < ActiveRecord::Migration
  def change
    add_column :availabilities, :implicitly_created, :boolean, default: false, null: false
  end
end
