desc "This task is called by the Heroku scheduler add-on"
task :decline_past_request_offers => :environment do
  Request.decline_past_offers
end