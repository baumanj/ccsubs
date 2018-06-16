class SessionsController < ApplicationController

  def new
  end

  def create
    user = User.find_by_email(params[:session][:email].downcase)
    if user.nil?
      flash.now[:error] = 'No account matching that email'
      render 'new'
    elsif current_user&.id == 1 && params[:sign_in_as_user] == 'true'
      session[:impersonated_user_id] = user.id
      flash[:success] = "Now signed in as #{user}"
      redirect_to :back
    else
      if params[:commit] == 'Reset password'
        if user.confirmed?
          user.update_confirmation_token
          mailer.reset_password(user).deliver_now
          flash.now[:success] = "Sent reset email to #{user.email}"
        else
          flash.now[:error] = 'Cannot send reset email to unconfirmed email address'
        end
        render 'forgot'
      elsif sign_in(user, params[:session][:password], params[:session][:auto_signout] == "1")
        url = session.delete(:pre_signin_url)
        redirect_to url || root_url
      else
        flash.now[:error] = 'Wrong password or email'
        render 'new'
      end
    end
  end

  def destroy
    sign_out
    redirect_to root_url
  end
end
