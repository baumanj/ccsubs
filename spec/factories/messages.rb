FactoryBot.define do
  factory :message do
    shift {Request.shifts.keys.sample}
    date {Faker::Date.between(from: 1.day.from_now, to: 1.year.from_now)}
    body {"MyText"}
  end
end