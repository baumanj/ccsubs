require_relative 'shared'

FactoryGirl.define do
  factory :holiday_request do
    date { Faker::Date.unique(:in_the_next_year) } # Make these only actual holidays?
    shift { Request.shifts.keys.sample }
  end
end
