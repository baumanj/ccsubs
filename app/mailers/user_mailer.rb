class UserMailer < ActionMailer::Base
  default from: "ccsubs <jonccsubs@shumi.org>"
  VOLUNTEER_SERVICES = "baumanj+volunteerservices@gmail.com"

  def confirm_email(user)
    @user = user
    mail to: user.email, subject: "Confirm your ccsubs email"
  end

  def notify_subee(req, fulfilling_user)
    @req = req
    @user = @req.user
    @fulfilling_user = fulfilling_user
    mail to: @user.email,
         subject: "Sub/Swap #{@req}: #{@fulfilling_user.name} subbing for #{@user.name}",
         cc: VOLUNTEER_SERVICES
  end

  def notify_subber(req, fulfilling_user)
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
         subject: "Sub/Swap #{@req}: swap accepted!"
  end

  def remind_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_swap.user
    mail to: @accepter.email,
         subject: "Sub/Swap #{@req}: swap accepted!"
  end

  def notify_swap_decline(req, offer_req)
    @req = req
    @decliner = req.user
    @declinee = offer_req.user
    mail to: @declinee.email,
         subject: "Sub/Swap #{@req}: swap declined 😭"
  end

  def reset_password(user)
    @user = user
    mail to: user.email, subject: "Reset your ccsubs password"
  end
end
