class RemoveReuqestIdFromAvailabilities < ActiveRecord::Migration
  def change
    remove_reference :availabilities, :request, index: true
  end
end
