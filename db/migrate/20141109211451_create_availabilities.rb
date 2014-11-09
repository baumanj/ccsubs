class CreateAvailabilities < ActiveRecord::Migration
  def change
    create_table :availabilities do |t|
      t.references :user, index: true
      t.references :request, index: true
      t.datetime :start

      t.timestamps
    end
  end
end
