class ChangeDefaultLocationForRequest < ActiveRecord::Migration
  def change
  	change_column_default :requests, :location, nil
  end
end
