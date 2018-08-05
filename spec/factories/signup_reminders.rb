require_relative 'shared'

FactoryGirl.define do
  factory :signup_reminder do
    transient { date Faker::Date.unique(:in_the_next_year) }
    day { date.day }
    month { date.month }
    year { date.year }
    user_ids "MyText"
    mailer_method "MyMailer"
    event_type :on_call
  end
end
