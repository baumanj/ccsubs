require 'csv'

class UsersController < ApplicationController
  before_action :require_signin, except: [:reset_password, :update_password]
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
      flash[:success] = "User #{@user} created"
      redirect_to @user
    else
      @errors = @user.errors
      render 'new' # Try again
    end
  end

  def new_list
  end

  def upload_csv
    if params[:csv].nil?
      flash[:error] = "Please specify a CSV file"
      render 'new_list'
    else
      user_array = CSV.parse(params[:csv].read)
      user_array.shift # discard header row
      vics = User.pluck(:vic)
      new_users = []
      user_array.each do |name, vic, email|
        unless vics.include? vic.to_i
          new_users << { name: name, email: email, vic: vic, password: vic }
        end
      end
      User.transaction do
        begin
          new_users = User.create!(new_users)
          if new_users.any?
            flash[:success] = "Added #{new_users.size} users: #{new_users.map(&:name).join(', ')}"
            if flash[:success].size > (ActionDispatch::Cookies::MAX_COOKIE_SIZE / 4)
              size = flash[:success].size
              flash[:success] = "Added #{new_users.size} users"
            end
          else
            flash[:notice] = "No new users added"
          end
          redirect_to users_path
        rescue ActiveRecord::RecordInvalid => invalid
          flash[:error] = "Upload failed because not all new users could be created!"
          @errors = invalid.record.errors
          render 'new_list'
          raise ActiveRecord::Rollback
        end
      end
    end
  end

  def send_confirmation
    @user = User.find(params[:id])
    @user.update_confirmation_token
    flash[:success] = "Confirmation email sent to #{@user.email}"
    mailer.confirm_email(@user).deliver
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
    if @user.update(user_params)
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
    if params[:user][:password].empty? && params[:user][:password_confirmation].empty?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end
    resend_confirmation =
      params[:user][:email].downcase != @user.email && @user.confirmed?
    if @user.update(user_params)
      flash[:success] = "Update successful"
      if @user.disabled?
        sign_out(@user)
      elsif resend_confirmation
        @user.update_confirmation_token
        flash[:success] += ". Confirmation email sent to #{@user.email}"
        mailer.confirm_email(@user).deliver
      end
      redirect_to @user
    else
      @errors = @user.errors
      render 'edit' # Try again
    end
  end

  # def create_request
  #   @user = User.find(params[:id])
  #   @user.assign_attributes(user_params)
  #   @request = @user.requests.find &:new_record?
  #   if @user.save
  #     redirect_to @request, flash: { success: "Request created" }
  #   else
  #     @errors = @user.errors
  #     @suggested_availabilities = availabilities_from_user_params
  #     render 'requests/specify_availability'
  #   end
  # end

  def update_availability
    @user = User.find(params[:id])
    message = "Set #{changed_availability_string}"
    if @user.update(user_params)
      flash[:success] = message
      redirect_to availabilities_path
    else
      @errors = @user.errors
      @suggested_availabilities = availabilities_from_user_params
      render 'availabilities/index'
    end
  end

  if Rails.env.development?
    def delete_all_availability
      User.find(params[:id]).availabilities.destroy_all
      redirect_to :back
    end
  end

  def index
    @users = User.all
  end

  def show
    @user = User.find(params[:id])
  end

  private

    def changed_availability_string
      values = user_params.fetch(:availabilities_attributes, {}).values
      true_values, false_values = values.partition {|v| v[:free] == "true" }
      s = "#{true_values.count} #{'shift'.pluralize(true_values.count)} free"
      if false_values.empty?
        s
      else
        s + " and #{false_values.count} #{'shift'.pluralize(false_values.count)} busy"
      end
    end

    def availabilities_from_user_params
      user_params[:availabilities_attributes].values.map do |attributes|
        Availability.find_or_initialize_by(attributes)
      end
    end

    def user_params
      u = params.require(:user)
      u.permit(:name, :email, :password, :password_confirmation, :disabled, :vic, :confirmation_token,
               availabilities_attributes: [:id, :date, :shift, :free],
               requests_attributes: [:date, :shift])
    end

end
