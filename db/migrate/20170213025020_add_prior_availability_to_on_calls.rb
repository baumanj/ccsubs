class AddPriorAvailabilityToOnCalls < ActiveRecord::Migration
  def change
    add_column :on_calls, :prior_availability, :boolean
  end
end
