FactoryGirl.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    vic { Faker::Number.number(5) }
    password Faker::Internet.password(min_length = 5)
  end
end