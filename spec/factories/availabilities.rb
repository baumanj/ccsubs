FactoryBot.define do
  factory :availability do
    user
    date {Faker::Date.between(from: 1.day.from_now, to: 1.year.from_now)}
    shift {Request.shifts.keys.sample}
    free {true}
  end
end