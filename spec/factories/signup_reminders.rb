require_relative 'shared'

FactoryGirl.define do
  factory :signup_reminder do
    transient { date Faker::Date.unique(:in_the_next_year) }
    month { date.month }
    year { date.year }
    user_ids "MyText"
    mailer_method "MyMailer"
  end
end
