class ChangeStorageOfAvailabilities < ActiveRecord::Migration
  def change

    add_column :availabilities, :shift, :integer
    add_column :availabilities, :date, :date

    hour_to_shift = {8 => 0, 12 => 1, 17 => 2, 21 => 3}

    Availability.transaction do
      Availability.all.each do |a|
        a.date = a.start.to_date
        a.shift = hour_to_shift.fetch(a.start.hour, 0)
        if a.save
          puts a.inspect
        else
          puts a.errors.inspect
          puts a.inspect
        end
      end
    end
    
    puts Availability.where(shift: nil).inspect
    
    change_column :availabilities, :shift, :integer, null: false
    change_column :availabilities, :date, :date, null: false

    remove_column :availabilities, :start
  end
end
