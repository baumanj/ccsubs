class RenameUserTypeToVolunteerType < ActiveRecord::Migration
  def change
    rename_column :users, :type, :volunteer_type
  end
end
