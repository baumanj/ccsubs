class UserMailer < ActionMailer::Base
  default from: "jonccsubs@shumi.org"

  def confirm_email(user)
    @user = user
    mail to: user.email, subject: "Confirm your ccsubs email"
  end

  def reset_password(user)
    @user = user
    mail to: user.email, subject: "Reset your ccsubs password"
  end
end
