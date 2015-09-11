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

  # Never send email to real addresses unless running in production
  # If not running the main app (e.g. ccsubs-preview) send mail to the current user instead of the
  # regular recipient, but keep the name of the real recipient to indicate who would receive what.
  def mail(headers)
    to_user = headers[:to]
    name = to_user.name
    if Rails.env.production?
      headers[:subject] = "[#{ENV['APP_NAME']}] #{headers[:subject]}"
      email = ENV['APP_NAME'] == 'ccsubs' ? to_user.email : @@active_user.email
    else
      email = "jon.#{to_user.email.sub('@', '.at.')}@shumi.org"
    end
    name = name.gsub('(', '\(').gsub!(')', '\)')
    headers[:to] = "#{name} <#{email}>"
    super
  end

  def confirm_email(user)
    @user = user
    mail to: user, subject: "Confirm your ccsubs email"
  end

  def notify_partial_match(req, half_matching_requests)
    @req = req
    @available_user = half_matching_requests.first.user
    @potential_swaps = half_matching_requests
    mail to: @req.user,
         subject: "Sub/Swap #{@req}: possible match"
  end

  def notify_match(req, matching_requests)
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
         subject: "Sub/Swap #{@req}: #{@fulfilling_user.name} subbing for #{@user.name}",
         cc: VOLUNTEER_SERVICES
  end

  def remind_sub(req, fulfilling_user)
    @req = req
    @fulfilling_user = fulfilling_user
    mail to: @fulfilling_user, subject: "Sub/Swap #{@req}: you have agreed to sub"
  end

  def notify_swap_offer(req, offer_req)
    @req = req
    @offer_req = offer_req
    mail to: @req.user,
         subject: "Sub/Swap #{@req}: swap offered! [ACTION REQUIRED]"
  end

  def notify_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_swap.user
    mail to: @acceptee,
         subject: "Sub/Swap #{@req}: #{@acceptee.name} swapping for #{@accepter.name} covering #{@req.fulfilling_swap}",
         cc: VOLUNTEER_SERVICES
  end

  def remind_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_swap.user
    mail to: @accepter,
         subject: "Sub/Swap #{@req}: swap from #{@acceptee} accepted for #{@req.fulfilling_swap}"
  end

  def notify_swap_decline(req, offer_req)
    @req = req
    @decliner = req.user
    @declinee = offer_req.user
    mail to: @declinee,
         subject: "Sub/Swap #{@req}: swap with #{@decliner.name} declined 😭"
  end

  def reset_password(user)
    @user = user
    mail to: user, subject: "Reset your ccsubs password"
  end
end
