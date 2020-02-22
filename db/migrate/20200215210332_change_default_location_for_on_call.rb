class ChangeDefaultLocationForOnCall < ActiveRecord::Migration
  def change
  	change_column_default :on_calls, :location, nil
  end
end
