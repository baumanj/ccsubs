FactoryGirl.define do
  factory :availability do
    user
    date Faker::Date.between(1.day.from_now, 1.year.from_now)
    shift Request.shifts.values.sample
    free true
  end
end