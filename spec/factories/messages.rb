FactoryGirl.define do
  factory :message do
    shift Request.shifts.keys.sample
    date Faker::Date.between(1.day.from_now, 1.year.from_now)
    body "MyText"
  end
end