class ChangeSubSwapStorageForRequests < ActiveRecord::Migration
  def change
      add_column :requests, :fulfilling_swap_id, :integer
      add_column :requests, :fulfilling_sub_id, :integer

      remove_column :requests, :fulfilling_user_id
      remove_column :requests, :swapped_shift
  end
end
