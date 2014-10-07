class CreateRequests < ActiveRecord::Migration
  def change
    create_table :requests do |t|
      t.time :start
      t.time :end
      t.integer :user_id
      t.boolean :fulfilled

      t.timestamps
    end
  end
end
