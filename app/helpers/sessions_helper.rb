module SessionsHelper

  # This hits the DB for every pageload; we can do better
  def sign_in(user, password)
    puts "******* in SessionsHelper#sign_in"
    remember_token = user.try_sign_in(password)
    puts "******* in SessionsHelper#sign_in, remember_token = #{remember_token}"
    if remember_token
      cookies.permanent[:remember_token] = remember_token
      self.current_user = user
    end
  end

  def sign_out(user=current_user)
    user.sign_out
    if user == current_user
      cookies.delete(:remember_token)
      self.current_user = nil
    end
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
    locked = obj.respond_to?(:locked?) ? obj.locked? : false
    !locked && (current_user_owns?(obj) || current_user.admin?)
  end

  def current_user_admin?
    signed_in? && current_user.admin?
  end

  def require_signin
    unless signed_in?
      session[:pre_signin_url] = request.url
      redirect_to signin_path, notice: "You must sign in to do that."
    end
  end
  
  def require_confirmed_email
    if !signed_in?
      require_signin
    elsif !current_user.confirmed?
      redirect_to current_user, notice: "You must confirm your email first"
    end
  end

  def check_authorization
    if params.include?(:id)
      user = current_user
      if user.nil?
        token = params[:user][:confirmation_token]
        requested_user = User.find(params[:id])
        if requested_user && requested_user.confirmation_token_valid?(token)
          user = requested_user
        end
      end

      if params[:id].to_i != user.id && !current_user_admin?
        redirect_to root_url, notice: "You don't have the rights to do that."
      end
    end
  end

  def require_admin
    unless signed_in? && current_user.admin?
      redirect_to root_url, notice: "You don't have the rights to do that."
    end
  end

  private

    def find_user_by_cookie
      remember_token_digest = User.digest(cookies.permanent[:remember_token])
      User.find_by_remember_token(remember_token_digest)
    end
end
