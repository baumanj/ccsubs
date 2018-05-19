desc "This task is called by the Heroku scheduler add-on"
task :decline_past_request_offers => :environment do
  Request.decline_past_offers
end

task :nag_unresponded_offer_owners, [:days_old] => :environment do |t, args|
  Request.nag_unresponded_offer_owners(args[:days_old])
end

task :stay_under_heroku_row_limit => :environment do
  Rails.application.eager_load! # probably only necessary in dev
  record_counts = Hash[ActiveRecord::Base.descendants.map {|table| [table.name, table.count] }]
  total = record_counts.values.reduce(&:+)
  puts "Record counts:\n#{record_counts}\nTotal: #{total}"

  # Heroku limit is 10,000 rows, start deleting when we get within 10% of the max
  num_to_delete = total - 9000

  if num_to_delete > 0
    destroyed = Availability.past.reorder(:date).limit(num_to_delete).destroy_all
    puts "Destroyed #{destroyed.count} oldest availabilities"
    num_to_delete -= destroyed.count
  else
    puts "Only #{Availability.count} availabilities; no need to destroy any"
  end

  if num_to_delete > 0
    destroyed = DefaultAvailability.joins(:user).where(users: {disabled: true}).limit(num_to_delete).destroy_all
    puts "Destroyed #{destroyed.count} default availabilities (of disabled users)"
    num_to_delete -= destroyed.count
  else
    puts "No need to destroy any default availabilities"
  end

  if num_to_delete > 0
    to_delete = Request.past.reorder(:date).limit(num_to_delete)
    to_delete.each(&:delete)
    puts "Deleted #{to_delete.count} oldest requests"
    num_to_delete -= to_delete.count
  else
    puts "Only #{Request.count} requests; no need to destroy any"
  end

  if num_to_delete > 0
    UserMailer.alert("Wanted to delete #{num_to_delete} more records\n#{record_counts}\nTotal: #{total}").deliver_now
  end
end

task :destroy_disabled_users_future_on_calls => :environment do
  OnCall.destroy_for_disabled_users
end

task :send_on_call_reminder => :environment do
  OnCallReminder.send_reminders
end

task :check_for_missing_phone => :environment do
  User.check_phone
end

task :create_holiday_requests => :environment do
  require "#{Rails.root}/app/helpers/application_helper"
  HolidayRequest.create_any_not_present
end
