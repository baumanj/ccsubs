desc "This task is called by the Heroku scheduler add-on"
task :decline_past_request_offers => :environment do
  Request.decline_past_offers
end

task :nag_unresponded_offer_owners, [:days_old] => :environment do |t, args|
  Request.nag_unresponded_offer_owners(args[:days_old])
end

task :destroy_oldest_past_availabilities => :environment do
  Availability.destroy_oldest_past
end

task :send_on_call_reminder => :environment do
  OnCallReminder.send_reminders
end