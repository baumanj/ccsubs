class RecreateOnCallIndex < ActiveRecord::Migration
  def change
  	add_index :on_calls, [:shift, :date, :location], unique: true
  end
end
