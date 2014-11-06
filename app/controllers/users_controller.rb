class UsersController < ApplicationController
  before_action :require_signin, except: [:new, :create]
  before_action :check_authorization
  before_action :require_admin, except: [:new, :create, :edit, :update, :show]

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
      @errors = @user.errors
      render 'new' # Try again
    end
  end

  def send_confirmation
    @user = User.find(params[:id])
    @user.create_confirmation_token
    flash[:success] = "Confirmation email sent to #{@user.email}"
    UserMailer.confirm_email(@user).deliver
    redirect_to @user
  end
  
  def confirm
    @user = User.find(params[:id])
    if @user.confirm(params[:confirmation_token])
      flash[:success] = "#{@user.email} confirmed!"
    else
      flash[:error] = "Confirmation failed"
    end
    redirect_to @user
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
      sign_out(@user) if @user.disabled?
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
                     :password_confirmation, :disabled)
    end
end
