require_relative 'shared'

FactoryBot.define do
  factory :holiday_request do
    date { Faker::Date.unique(:holiday_in_next_year) }
    shift { Request.shifts.keys.sample }
  end
end
