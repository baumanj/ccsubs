class UsersController < ApplicationController
  before_action :require_signin, except: [:new, :create, :reset_password, :update_password]
  before_action :check_authorization, except: [:reset_password]
  before_action :require_admin, only: [:new, :create, :index]

  def new
    @user = User.new
  end
  
  def create
    @user = User.new(user_params)
    @user.password = @user.vic # TODO: email users for initial pass?
    if @user.save
      # sign_in @user # If we want to sign in upon sign-up
      flash[:success] = "User #{@user.name} created"
      redirect_to @user
    else
      @errors = @user.errors
      render 'new' # Try again
    end
  end

  def new_list
  end

  def upload_csv
    require 'csv'
    if params[:csv].nil?
      flash[:error] = "Please specify a CSV file"
      render 'new_list'
    else
      user_array = CSV.parse(params[:csv].read)
      user_array.shift # discard header row
      @new_users = []
      User.transaction do
        user_array.each do |name, vic, email|
          user = User.new(name: name, email: email, vic: vic, password: vic)
          @new_users << user if user.save
        end
        if @new_users.any?
          flash[:success] = "Added #{@new_users.size} users: #{@new_users.map(&:name).join(', ')}"
          if flash[:success].size > (ActionDispatch::Cookies::MAX_COOKIE_SIZE / 4)
            size = flash[:success].size
            flash[:success] = "Added #{@new_users.size} users"
          end
        else
          flash[:notice] = "No new users added"
        end
      end
      redirect_to users_path
    end
  end

  def send_confirmation
    @user = User.find(params[:id])
    @user.update_confirmation_token
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

  def reset_password
    @user = User.find(params[:id])
    if @user.confirmation_token_valid?(params[:confirmation_token])
      # Each link can only be used once
      @user.update_confirmation_token
    else
      flash[:error] = "This password reset link is invalid"
      redirect_to signin_url
    end
  end

  def update_password
    @user = User.find(params[:id])
    if @user.update_attributes(user_params)
      # Each link can only be used once
      @user.update_confirmation_token
      flash[:success] = "Update successful"
      redirect_to signin_url
    else
      @errors = @user.errors
      render 'reset_password' # Try again
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
    resend_confirmation =
      params[:user][:email].downcase != @user.email && @user.confirmed?
    if @user.update_attributes(user_params)
      flash[:success] = "Update successful"
      if @user.disabled?
        sign_out(@user)
      elsif resend_confirmation
        @user.update_confirmation_token
        flash[:success] += ". Confirmation email sent to #{@user.email}"
        UserMailer.confirm_email(@user).deliver
      end
      redirect_to @user
    else
      @errors = @user.errors
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
                     :password_confirmation, :disabled, :vic, :confirmation_token)
    end
end
