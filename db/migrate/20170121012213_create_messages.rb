class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.integer :shift, null: false
      t.datetime :date, null: false
      t.text :body

      t.timestamps
    end
  end
end
