class CreateOnCallIndex < ActiveRecord::Migration
  def change
    add_index :on_calls, [:shift, :date], unique: true
  end
end
