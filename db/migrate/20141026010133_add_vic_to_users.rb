class AddVicToUsers < ActiveRecord::Migration
  def change
    add_column :users, :vic, :integer
    add_index  :users, :vic, unique: true
  end
end
