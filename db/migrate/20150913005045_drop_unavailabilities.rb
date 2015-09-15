class DropUnavailabilities < ActiveRecord::Migration
  def change
  	drop_table :unavailabilities
  end
end
