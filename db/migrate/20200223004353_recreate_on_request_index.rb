class RecreateOnRequestIndex < ActiveRecord::Migration
  def change
    # Fix HolidayRequests
    # Confirm only seeking_offers/fulfilled exist
    if HolidayRequest.seeking_offers.count + HolidayRequest.fulfilled.count != HolidayRequest.count
      raise
    end

    HolidayRequest.transaction do
      # Update fulfilled to location of fulfilling_user
      HolidayRequest.after(ShiftTime::LOCATION_CHANGE_DATE).fulfilled.each do |hr|
        hr.location = hr.fulfilling_user.location
        hr.save!
      end

      # Remove any for the Northgate location
      HolidayRequest.after(ShiftTime::LOCATION_CHANGE_DATE).Northgate.seeking_offers.delete_all
      if HolidayRequest.after(ShiftTime::LOCATION_CHANGE_DATE).Northgate.any?
        puts "Should be no Northgate requests after change"
        raise ActiveRecord::Rollback
      end

      HolidayRequest.create_any_not_present

      if HolidayRequest.after(ShiftTime::LOCATION_CHANGE_DATE).Belltown.count != HolidayRequest.after(ShiftTime::LOCATION_CHANGE_DATE).Renton.count
        puts "Should be the same number of Belltown and Renton HolidayRequests"
        raise ActiveRecord::Rollback
      end
    end

    Request.transaction do
      Request.after(ShiftTime::LOCATION_CHANGE_DATE).each do |r|
        r.location = r.user.location
        raise ActiveRecord::Rollback if r.location == 0
        if r.fulfilling_user && r.user.location != r.fulfilling_user.location
          puts "Location mismatch: #{r.inspect}"
          r.save(validation: false)
        else
          r.save!
      end
      end
    end

    add_index :requests, [:user_id, :shift, :date, :location], unique: true
  end
end
