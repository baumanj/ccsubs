class AddTypeToRequest < ActiveRecord::Migration
  def change
    add_column :requests, :type, :string, null: false, default: "Request"
  end
end
