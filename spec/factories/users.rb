module Faker
  class Number
    def self.vic
      loop do
        new_vic = Faker::Number.number(5)
        return new_vic unless User.exists?(vic: new_vic)
      end
    end
  end
end

FactoryGirl.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    admin false
    vic { Faker::Number.vic }
    password Faker::Internet.password(min_length = 5)
    confirmed false
    disabled false

    factory :confirmed_user do
      after(:create) do |u|
        u.update_confirmation_token
        u.confirm(u.confirmation_token)
      end
    end
  end
end
