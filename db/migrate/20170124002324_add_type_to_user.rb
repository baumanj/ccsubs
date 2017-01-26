class AddTypeToUser < ActiveRecord::Migration
  def change
    add_column :users, :type, :integer
    add_column :users, :home_phone, :string
    add_column :users, :cell_phone, :string
  end
end
