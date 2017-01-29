require 'csv'

class UsersController < ApplicationController
  before_action :require_signin, except: [:reset_password, :update_password]
  before_action :check_authorization, except: [:reset_password]
  before_action :require_admin, only: [:new, :create, :index]

  EXPECTED_CSV_HEADERS = ['name', 'vic', 'email']

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
      headers = user_array.shift.compact # discard header row
      unless headers.size == EXPECTED_CSV_HEADERS.size
          flash[:error] = "Expected CSV to have 3 columns (#{EXPECTED_CSV_HEADERS.join(', ')}); found #{headers.size} (#{headers.join(', ')})"
          render 'new_list'
          return
      end
      vics = User.pluck(:vic).compact
      new_users = []
      user_array.each do |name, vic, email|
        unless vics.include? vic.to_i
          new_users << { name: name, email: email, vic: vic, password: vic }
        end
      end

      # We don't handle the case where an existing disabled user is reenabled (yet)
      input_vics = user_array.map {|x| x[1].to_i }
      enabled_vics = User.where(disabled: false).pluck(:vic).compact
      to_disable = enabled_vics - input_vics

      User.transaction do
        begin
          new_users = User.create!(new_users)
          # update_all goes directly to the DB, so doesn't change 'updated_at' automatically
          num_disabled = User.where(vic: to_disable).update_all(disabled: true, updated_at: DateTime.current)
          if new_users.any?
            flash[:success] = "Added #{new_users.size} users: #{new_users.map(&:name).join(', ')}"
            if flash[:success].size > (ActionDispatch::Cookies::MAX_COOKIE_SIZE / 4)
              size = flash[:success].size
              flash[:success] = "Added #{new_users.size} users"
            end
            flash[:success] += ". Disabled #{num_disabled} users" unless num_disabled.zero?
          else
            flash[:notice] = "No new users added"
            flash[:notice] += ". #{num_disabled} users disabled" unless num_disabled.zero?
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
    mailer.confirm_email(@user).deliver_now
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
        mailer.confirm_email(@user).deliver_now
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
    # Omit availabilities that the user hasn't specified 'Yes' or 'No'
    specified_availabilities = user_params[:availabilities_attributes].reject {|_, a| a[:free].nil? }
    up = ActionController::Parameters.new(availabilities_attributes: specified_availabilities)
    up.permit! # We already filtered in user_params
    if @user.update(up)
      flash[:success] = message
      redirect_to params[:redirect_to] || availabilities_path
    else
      @errors = @user.errors
      @suggested_availabilities = availabilities_from_user_params
      render 'availabilities/index'
    end
  end

  def update_default_availability
    @user = User.find(params[:id])
    if @user.update(user_params)
      # raise
      flash[:success] = "Updated typical availability"
      redirect_to params[:redirect_to] || edit_default_availability_path
    else
      @errors = @user.errors
      @default_availabilities = default_availabilities_from_user_params
      render 'availabilities/edit_default'
    end
  end

  if Rails.env.development?
    def delete_all_availability
      User.find(params[:id]).availabilities.destroy_all
      redirect_to :back
    end
  end

  def index
    @admins, non_admins = User.order(:name).partition(&:admin)
    @disabled_users, @enabled_users = non_admins.partition(&:disabled)
  end

  def show
    @user = User.find(params[:id])
  end

  private

    def changed_availability_string
      values = user_params.fetch(:availabilities_attributes, {}).values
      true_values = values.select {|v| v[:free] == "true" }
      false_values = values.select {|v| v[:free] == "false" }
      "#{true_values.count} #{'shift'.pluralize(true_values.count)} free and " \
      "#{false_values.count} #{'shift'.pluralize(false_values.count)} busy"
    end

    def availabilities_from_user_params
      user_params[:availabilities_attributes].values.map do |attributes|
        Availability.find_or_initialize_by(attributes)
      end
    end

    def default_availabilities_from_user_params
      user_params[:default_availabilities_attributes].values.map do |attributes|
        DefaultAvailability.find_or_initialize_by(attributes)
      end
    end

    def user_params
      params.require(:user).permit(:name, :email, :password, :password_confirmation, :disabled, :vic, :confirmation_token,
                                   availabilities_attributes: [:id, :date, :shift, :free],
                                   default_availabilities_attributes: [:id, :cwday, :shift, :free],
                                   requests_attributes: [:date, :shift])
    end

end
