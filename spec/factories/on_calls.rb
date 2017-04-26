require_relative 'shared'

FactoryGirl.define do
  factory :on_call do
    date { Faker::Date.unique(:in_the_on_call_range) }
    shift OnCall.shifts.keys.sample
    user
  end
end
