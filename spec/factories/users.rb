module Faker
  class Number
    def self.vic
      @previously_selected ||= Set.new
      100.times do
        new_vic = Faker::Number.number(digits: 5)
        if !@previously_selected.include?(new_vic) && !User.exists?(vic: new_vic)
          @previously_selected.add(new_vic)
          return new_vic
        end
      end

      raise "Couldn't find unique vic after many tries"
    end
  end

  class Name
    def self.unique_name
      @previously_selected ||= Set.new
      100.times do
        new_name = name
        if !@previously_selected.include?(new_name)
          @previously_selected.add(new_name)
          return new_name
        end
      end

      raise "Couldn't find unique name after many tries"
    end
  end
end

FactoryBot.define do
  factory :user do
    name { Faker::Name.unique_name }
    email { Faker::Internet.email }
    volunteer_type { User.volunteer_types.keys.sample }
    home_phone { Faker::PhoneNumber.phone_number }
    cell_phone { Faker::PhoneNumber.phone_number }
    admin {false}
    staff {false}
    vic { Faker::Number.vic }
    password {Faker::Internet.password(min_length: 5)}
    confirmed {false}
    disabled {false}
    location { ShiftTime::LOCATIONS_AFTER.sample }

    factory :confirmed_user do
      after(:create) do |u|
        u.update_confirmation_token
        u.confirm(u.confirmation_token)
      end

      factory :admin do
        admin {true}
      end
    end

    factory :recurring_shift_volunteer do
      volunteer_type { User.volunteer_types.fetch_values('Regular Shift', 'Alternating').sample }
    end

    factory :non_recurring_shift_volunteer do
      volunteer_type { (User.volunteer_types.values - User.volunteer_types.fetch_values('Regular Shift', 'Alternating')).sample }
    end
  end
end
