module SessionsHelper

  def sign_in(user)
    remember_token = User.new_remember_token
    cookies.permanent[:remember_token] = remember_token
    user.update_attribute(:remember_token, User.digest(remember_token))
    self.current_user = user
  end

  def sign_out
    current_user.update_attribute(:remember_token,
                                  User.digest(User.new_remember_token))
    cookies.delete(:remember_token)
    self.current_user = nil
  end

  def signed_in?
    !current_user.nil?
  end

  def current_user=(user)
    @current_user = user
  end

  def current_user
    @current_user ||= find_user_by_cookie
  end

  def current_user_owns?(obj)
    current_user && current_user.id == obj.user.id
  end

  def current_user_can_edit?(obj)
    current_user_owns?(obj) || current_user.admin?
  end

  def require_signin
    unless signed_in?
      session[:pre_signin_url] = request.url
      redirect_to signin_path, notice: "You must sign in to do that."
    end
  end

  def check_authorization
    if params.include?(:id) && params[:id].to_i != current_user.id &&
      !current_user.admin?
      redirect_to root_url, notice: "You don't have the rights to do that."
    end
  end

  def require_admin
    unless current_user.admin?
      redirect_to root_url, notice: "You don't have the rights to do that."
    end
  end

  private

    def find_user_by_cookie
      remember_token_digest = User.digest(cookies.permanent[:remember_token])
      User.find_by_remember_token(remember_token_digest)
    end
end
