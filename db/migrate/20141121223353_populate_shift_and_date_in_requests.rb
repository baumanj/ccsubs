class PopulateShiftAndDateInRequests < ActiveRecord::Migration
  def change
    hour_to_shift = {8 => 0, 12 => 1, 17 => 2, 21 => 3}

    Request.transaction do
      Request.all.each do |r|
        r.date = r.start.to_date
        r.shift = hour_to_shift.fetch(r.start.hour, 0)
        r.save
      end
    end
    
    change_column :requests, :shift, :integer, null: false
    change_column :requests, :date, :date, null: false
  end
end
