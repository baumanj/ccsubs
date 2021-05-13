require "#{Rails.root}/app/helpers/application_helper"

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
    # Only select availabilties that aren't associated with a request
    # We need to keep this info for holiday fulfillment tracking
    destroyed = Availability.destroy_all(id: Availability.past.reorder(:date).reject(&:request).first(num_to_delete).map(&:id))
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
    destroyed = OnCall.joins(:user).where(users: {disabled: true}).limit(num_to_delete).destroy_all
    puts "Destroyed #{destroyed.count} on-calls (of disabled users)"
    num_to_delete -= destroyed.count
  else
    puts "No need to destroy any on-calls of disabled users"
  end

  if num_to_delete > 0
    destroyed = OnCall.where("date < :a_year_ago", {a_year_ago: 1.year.ago}).limit(num_to_delete).destroy_all
    puts "Destroyed #{destroyed.count} old on-calls (shifts over 1 year ago)"
    num_to_delete -= destroyed.count
  else
    puts "No need to destroy any old on-calls"
  end

  if num_to_delete > 0
    destroyed = SignupReminder.where("created_at < :a_year_ago", {a_year_ago: 1.year.ago}).limit(num_to_delete).destroy_all
    puts "Destroyed #{destroyed.count} signup reminders"
    num_to_delete -= destroyed.count
  else
    puts "No need to destroy any signup reminders"
  end

  if num_to_delete > 0
    destroyed = Message.where("date < :a_month_ago", {a_month_ago: 1.month.ago}).limit(num_to_delete).destroy_all
    puts "Destroyed #{destroyed.count} messages (for shifts over 1 month ago)"
    num_to_delete -= destroyed.count
  else
    puts "No need to destroy any messages"
  end

  if num_to_delete > 0
    # This doesn't delete any holiday requests, but at some point we may need to
    # As long as we prioritize the unfulfilled ones and then the ones which are
    # 2+ years old, we shouldn't lose any important data
    to_delete = Request.past.reorder(:date).limit(num_to_delete)
    to_delete.each(&:delete)
    puts "Deleted #{to_delete.count} oldest requests"
    num_to_delete -= to_delete.count
  else
    puts "Only #{Request.count} requests; no need to destroy any"
  end

  # Uncomment if we need to delete old users
  if num_to_delete > 0
    destroyed = User.where(disabled: true, admin: false).where("updated_at < :a_year_ago", {a_year_ago: 1.year.ago}).limit(num_to_delete).destroy_all
    puts "Destroyed #{destroyed.count} disabled users that hadn't been updated in over a year"
    num_to_delete -= destroyed.count
  else
    puts "No need to destroy any users"
  end

  if num_to_delete > 0
    UserMailer.alert("Wanted to delete #{num_to_delete} more records\n#{record_counts}\nTotal: #{total}").deliver_now
  end
end

# Remove after updating scheduler to call cleanup_for_disabled_users instead
task :destroy_disabled_users_future_on_calls => :environment do
  OnCall.destroy_for_disabled_users
end

task :cleanup_for_disabled_users => :environment do
  OnCall.destroy_for_disabled_users
  HolidayRequest.reset_for_disabled_users
end

# Remove after updating scheduler to call send_reminders instead
task :send_on_call_reminder => :environment do
  SignupReminder.send_for_on_call
end

task :send_reminders => :environment do
  SignupReminder.send_for_on_call
  SignupReminder.send_for_holiday
end

task :check_for_missing_phone => :environment do
  User.check_phone
end

task :create_holiday_requests => :environment do
  HolidayRequest.create_any_not_present
end
