class AddRegularShiftToUser < ActiveRecord::Migration
  def change
    add_column :users, :regular_shift, :integer
    add_column :users, :regular_cwday, :integer
  end
end
