class UsersController < ApplicationController
  before_action :require_signin, except: [:new, :create]
  before_action :check_authorization
  before_action :require_admin, except: [:new, :create, :edit, :show]

  def new
    @user = User.new
  end
  
  def create
    @user = User.new(user_params)
    if @user.save
      # sign_in @user # If we want to sign in upon sign-up
      flash[:success] = "Welcome, #{@user.name}"
      redirect_to @user
    else
      render 'new' # Try again
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if params[:user][:password].empty? &&  params[:user][:password_confirmation].empty?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end
    if @user.update_attributes(user_params)
      flash[:success] = "Update successful"
      redirect_to @user
    else
      render 'edit' # Try again
    end
  end

  def index
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
  end

  private

    def user_params
      params.require(:user).permit(:name, :email, :password,
                     :password_confirmation)
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
end
