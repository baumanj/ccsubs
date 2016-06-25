class UserMailer < ActionMailer::Base
  VOLUNTEER_SERVICES = if Rails.env.production?
    "volunteerservices@crisisclinic.org"
  else
    "baumanj+volunteerservices@gmail.com" 
  end
  default from: "ccsubs <#{VOLUNTEER_SERVICES}>"

  def self.active_user=(user)
    @@active_user = user
  end

  # Never send email to real addresses unless running in production on heroku
  # - In development or locally-run production, always send to @shumi.org
  # - In test, no emails are actually sent, but use the real headers
  # If not running the main app (e.g. ccsubs-preview) send mail to the current user instead of the
  # regular recipient, but keep the name of the real recipient to indicate who would receive what.
  def mail(headers)
    to_user = headers[:to]
    name = to_user.name
    local_production = Rails.env.production? && ENV['DYNO'].nil?
    if Rails.env.development? || local_production
      email = "jon.#{to_user.email.sub('@', '.at.')}@shumi.org"
    else
      headers[:subject] = "[#{ENV['APP_NAME']}] #{headers[:subject]}"
      email = ENV['APP_NAME'] == 'ccsubs' ? to_user.email : @@active_user.email
    end
    name = name.gsub('(', '\(').gsub!(')', '\)')
    headers[:to] = "#{name} <#{email}>"
    super
  end

  def confirm_email(user)
    @user = user
    mail to: user, subject: "Confirm your ccsubs email"
  end

  def notify_potential_matches(req, half_matching_requests)
    @req = req
    @available_user = half_matching_requests.first.user
    @potential_swaps = half_matching_requests
    mail to: @req.user,
         subject: "Sub/Swap #{@req}: potential match found"
  end

  def notify_full_matches(req, matching_requests)
    @req = req
    @available_user = matching_requests.first.user
    @suggested_swaps = matching_requests
    mail to: @req.user,
         subject: "Sub/Swap #{@req}: match found! [ACTION REQUIRED]"
  end

  def notify_sub(req, fulfilling_user)
    @req = req
    @fulfilling_user = fulfilling_user
    mail to: @req.user,
         subject: "Sub/Swap #{@req}: #{@fulfilling_user} subbing for #{@user}",
         cc: VOLUNTEER_SERVICES
  end

  def remind_sub(req, fulfilling_user)
    @req = req
    @fulfilling_user = fulfilling_user
    mail to: @fulfilling_user, subject: "Sub/Swap #{@req}: you have agreed to sub"
  end

  def notify_swap_offer(from: nil, to: nil)
    raise ArgumentError if from.nil? || to.nil? # need ruby 2.1
    @received_offer_request = to
    @sent_offer_request = from
    mail to: @received_offer_request.user,
         subject: "Sub/Swap #{@received_offer_request}: swap offered! [ACTION REQUIRED]"
  end

  def notify_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_user
    mail to: @acceptee,
         subject: "Sub/Swap #{@req}: #{@acceptee} swapping for #{@accepter} covering #{@req.fulfilling_swap}",
         cc: VOLUNTEER_SERVICES
  end

  def remind_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_user
    mail to: @accepter,
         subject: "Sub/Swap #{@req}: swap from #{@acceptee} accepted for #{@req.fulfilling_swap}"
  end

  def notify_swap_decline(decliners_request: req, offerers_request: offer_req)
    @decliners_request = decliners_request
    @decliner = decliners_request.user
    @declinee = offerers_request.user
    mail to: @declinee,
         subject: "Sub/Swap #{offerers_request}: swap with #{@decliner} declined 😭"
  end

  def reset_password(user)
    @user = user
    mail to: user, subject: "Reset your ccsubs password"
  end
end
