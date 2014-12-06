class UserMailer < ActionMailer::Base
  default from: "jonccsubs@shumi.org"

  def confirm_email(user)
    @user = user
    mail to: user.email, subject: "Confirm your ccsubs email"
  end

  def notify_sub(req)
    @req = req
    @user = @req.user
    @fulfilling_user = @req.fulfilling_user
    mail to: @user.email, subject: "Sub/Swap #{@req}: sub found!"
  end

  def notify_swap_offer(req, availability)
    @req = req
    @availability = availability
    @user = @req.user
    @fulfilling_user = @req.fulfilling_user
    mail to: @user.email,
         subject: "Sub/Swap #{@req}: swap offered! [ACTION REQUIRED]"
  end

  def notify_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_user
    mail to: @acceptee.email,
         subject: "Sub/Swap #{@req}: swap accepted!"
  end

  def notify_swap_decline(req, declinee)
    @req = req
    @decliner = req.user
    @declinee = declinee
    mail to: @declinee.email,
         subject: "Sub/Swap #{@req}: swap declined 😭"
  end

  def reset_password(user)
    @user = user
    mail to: user.email, subject: "Reset your ccsubs password"
  end
end
