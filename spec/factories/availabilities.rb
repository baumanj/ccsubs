FactoryBot.define do
  factory :availability do
    user
    date {Faker::Date.unique(:in_the_next_year)}
    shift {Request.shifts.keys.sample}
    free {true}
  end
end