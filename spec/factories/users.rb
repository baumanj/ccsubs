module Faker
  class Number
    def self.unique_number(digits)
      @previously_selected ||= []
      raise if @previously_selected.size >= 10**digits
      loop do
        n = number(digits)
        unless @previously_selected.include?(n)
          @previously_selected << n
          return n
        end
      end
    end
  end
end

FactoryGirl.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    vic { Faker::Number.unique_number(5) }
    password Faker::Internet.password(min_length = 5)
  end
end