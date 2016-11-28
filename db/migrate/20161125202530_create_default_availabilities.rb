class CreateDefaultAvailabilities < ActiveRecord::Migration
  def change
    create_table :default_availabilities do |t|
      t.references :user, index: true
      t.integer :cwday
      t.integer :shift
      t.boolean :free

      t.timestamps
    end
  end
end
