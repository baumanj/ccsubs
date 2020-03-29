require_relative 'shared'

FactoryBot.define do
  factory :holiday_request do
    date { Faker::Date.unique(:holiday_in_next_year) }
    shift { Request.shifts.keys.sample }
    location do
        if date < ShiftTime::LOCATION_CHANGE_DATE
            ShiftTime::LOCATION_BEFORE
        else
            ShiftTime::LOCATIONS_AFTER.sample
        end
    end
  end
end
