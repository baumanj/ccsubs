require_relative 'shared'

FactoryGirl.define do
  factory :on_call_reminder do
    transient { date Faker::Date.unique(:in_the_on_call_range) }
    month { date.month }
    year { date.year }
    user_ids "MyText"
    mailer_method "MyMailer"
  end
end
