require 'csv'

class UsersController < ApplicationController
  before_action :require_signin, except: [:confirm, :reset_password, :update_password]
  before_action :check_authorization, except: [:confirm, :reset_password, :show]
  before_action :require_admin, only: [:new, :create, :index, :new_list, :upload_csv]

  EXPECTED_CSV_HEADERS = ['name', 'volunteer_type', 'vic', 'home_phone', 'cell_phone', 'email', 'location']

  def new_list
    @users_with_failed_update = []
  end

  def upload_csv
    @users_with_failed_update = []

    if params[:csv].nil?
      flash[:error] = "Please specify a CSV file"
      render 'new_list'
    else
      csv_rows = CSV.parse(params[:csv].read)
      headers = csv_rows.none? ? [] : csv_rows.shift.compact # discard header row
      unless headers.size == EXPECTED_CSV_HEADERS.size
        flash[:error] = "Expected CSV to have #{EXPECTED_CSV_HEADERS.size} columns (#{EXPECTED_CSV_HEADERS.join(', ')}); found #{headers.size} (#{headers.join(', ')})"
        render 'new_list'
        return
      end

      existing_users = User.where.not(vic: nil)
      existing_users_by_vic = existing_users.index_by(&:vic)
      existing_users_by_id = existing_users.index_by(&:id)
      new_users = []
      input_vics = []
      users_to_update = {} # id => attributes hash
      csv_rows.each do |name, volunteer_type, vic, home_phone, cell_phone, email, location|
        input_vics << vic.to_i
        csv_attributes = {
            name: name,
            volunteer_type: volunteer_type,
            home_phone: home_phone,
            cell_phone: cell_phone,
            location: location,
            disabled: false,
        }

        user = existing_users_by_vic[vic.to_i]
        begin
          if user
            if user.email.downcase != email.downcase
              puts "#{user.name}'s email (#{user.email}) doesn't match volgisics: #{email}"
            end

            user.attributes = csv_attributes # don't save; just use to test for change
            users_to_update[user.id] = csv_attributes if user.changed?
          else
            csv_attributes.merge!(
              email: email,
              vic: vic,
              password: vic
            )
            new_users << csv_attributes
          end
        rescue ArgumentError => error
          flash[:error] = "Update canceled due to invalid input. Could not add user '#{csv_attributes[:name]}' because #{error}."
          puts flash[:error]
          render 'new_list'
          return
        end
      end

      users_to_update.each do |user_id, new_attributes|
        user_to_update = existing_users_by_id[user_id]
        if !user_to_update.valid?
          @users_with_failed_update << user_to_update
        end
      end

      if @users_with_failed_update.any?
        flash[:error] = "Update canceled due to unsupported user " + 'update'.pluralize(@users_with_failed_update.size)
        render 'new_list'
        return
      end

      enabled_vics = User.where(disabled: false).pluck(:vic).compact
      vics_to_disable = enabled_vics - input_vics

      if vics_to_disable.size > (enabled_vics.size / 10)
        if params[:users_to_disable_confirmation].to_i == vics_to_disable.size
          message = "Disabing #{vics_to_disable.size} users with confirmed update"
          puts message
          UserMailer.alert(message).deliver_now
        else
          flash[:error] = "Update canceled since this would disable #{vics_to_disable.size} of the #{enabled_vics.size} currently enabled users. The provided user list should contain all users, not just new ones."
          puts flash[:error]
          @users_to_disable = User.where(vic: vics_to_disable)
          render 'new_list'
          return
        end
      end

      User.transaction do
        begin
          User.update(users_to_update.keys, users_to_update.values)
          new_users = User.create!(new_users)
          # update_all goes directly to the DB, so doesn't change 'updated_at' automatically
          num_disabled = User.where(vic: vics_to_disable).update_all(disabled: true, updated_at: DateTime.current)
          flash[:success] = "Added #{new_users.size} #{'user'.pluralize(new_users.size)}. " +
            "Updated #{users_to_update.size} #{'user'.pluralize(users_to_update.size)}. " +
            "Disabled #{num_disabled} #{'user'.pluralize(num_disabled)}."
          redirect_to users_path
        rescue ActiveRecord::RecordInvalid => invalid
          flash[:error] = "Upload failed because new user '#{invalid.record.name}' couldn't be created! #{invalid.record.errors.to_a}"
          @errors = invalid.record.errors
          puts flash[:error]
          render 'new_list'
          raise ActiveRecord::Rollback
        rescue ArgumentError => error
          flash[:error] = "Update canceled due to invalid input. #{error}."
          puts flash[:error]
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
    if current_user == @user
      redirect_to @user
    else
      redirect_to signin_path
    end
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
    if @user.update(user_params.merge(disabled: false))
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
    unless current_user.staff_or_admin?
      redirect_to edit_user_path(params[:id])
    end
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
      params.require(:user).permit(:name, :email, :password, :password_confirmation, :disabled,
                                   :vic, :confirmation_token, :first_day_of_week_preference,
                                   availabilities_attributes: [:id, :date, :shift, :free],
                                   default_availabilities_attributes: [:id, :cwday, :shift, :free],
                                   requests_attributes: [:date, :shift])
    end

end
