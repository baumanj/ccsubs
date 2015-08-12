class UserMailer < ActionMailer::Base
  default from: "ccsubs <volunteerservices@crisisclinic.org>"
  VOLUNTEER_SERVICES = if Rails.env.production?
    "volunteerservices@crisisclinic.org"
  else
    "baumanj+volunteerservices@gmail.com" 
  end

  def confirm_email(user)
    @user = user
    mail to: user.email, subject: "Confirm your ccsubs email"
  end

  def notify_sub(req, fulfilling_user)
    @req = req
    @user = @req.user
    @fulfilling_user = fulfilling_user
    mail to: @user.email,
         subject: "Sub/Swap #{@req}: #{@fulfilling_user.name} subbing for #{@user.name}",
         cc: VOLUNTEER_SERVICES
  end

  def remind_sub(req, fulfilling_user)
    @req = req
    @user = @req.user
    @fulfilling_user = fulfilling_user
    mail to: @fulfilling_user.email, subject: "Sub/Swap #{@req}: you have agreed to sub"
  end

  def notify_swap_offer(req, offer_req)
    @req = req
    @offer_req = offer_req
    mail to: @req.user.email,
         subject: "Sub/Swap #{@req}: swap offered! [ACTION REQUIRED]"
  end

  def notify_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_swap.user
    mail to: @acceptee.email,
         subject: "Sub/Swap #{@req}: #{@acceptee.name} swapping for #{@accepter.name} covering #{@req.fulfilling_swap}",
         cc: VOLUNTEER_SERVICES
  end

  def remind_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_swap.user
    mail to: @accepter.email,
         subject: "Sub/Swap #{@req}: swap from #{@acceptee} accepted for #{@req.fulfilling_swap}"
  end

  def notify_swap_decline(req, offer_req)
    @req = req
    @decliner = req.user
    @declinee = offer_req.user
    mail to: @declinee.email,
         subject: "Sub/Swap #{@req}: swap with #{@decliner.name} declined 😭"
  end

  def reset_password(user)
    @user = user
    mail to: user.email, subject: "Reset your ccsubs password"
  end
end
