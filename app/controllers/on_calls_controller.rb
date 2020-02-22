class OnCallsController < ApplicationController
  before_action :require_signin
  before_action :require_admin, except: [:index, :edit, :create]

  def index
    if !current_user.staff_or_admin?
      redirect_to edit_on_call_path
    elsif params[:location].nil? || params[:date].nil? || wrong_location_for_date
      date = params.fetch(:date, Date.current).to_date
      if date < ShiftTime::LOCATION_CHANGE_DATE
        redirect_to on_calls_path(location: User.locations.keys.first, date: date)
      else
        @date = date
        render 'choose_location'
      end
    else
      set_date_range_and_on_calls(params[:location])
    end
  end

  def edit
    if current_user.staff_or_admin?
      redirect_to on_calls_path
    elsif params[:date].nil?
      date = Date.current
      location = current_user.location_for(date)
      redirect_to edit_on_call_path(location: location, date: date)
    elsif params[:location] != current_user.location_for(params[:date])
      redirect_to edit_on_call_path(date: params[:date], location: current_user.location_for(params[:date]))
    else
      set_date_range_and_on_calls(params[:location])
    end
  end

  def create
    @on_call =
      OnCall.where(date: on_call_params[:date].to_date.all_month, user: current_user).first ||
      OnCall.new(user: current_user)

    if @on_call.update(on_call_params)
      flash[:success] = "On call for #{@on_call.date.strftime('%B')} saved"
      mailer.confirm_on_call_signup(@on_call).deliver_now
      redirect_to edit_on_call_path(location: @on_call.location, date: @on_call.date)
    else
      @errors = @on_call.errors
      set_date_range_and_on_calls(on_call_params[:location])
      render 'edit' # Try again
    end
  end

  def destroy
    on_call= OnCall.find(params[:id])
    if on_call.start.past?
      flash[:error] = "On calls cannot be deleted once their start time has passed"
    else
      on_call.destroy
      flash[:success] = "Deleted #{on_call.user}'s #{on_call} on-call shift"
    end

    redirect_to :back
  end

  private

    def set_date_range_and_on_calls(location)
      @location = location
      date = params.fetch(:date, Date.current).to_date
      if date < OnCall::FIRST_VALID_DATE
        date = OnCall::FIRST_VALID_DATE
        flash[:alert] = "Online on-call signup is not availble before #{OnCall::FIRST_VALID_DATE}"
        redirect_to on_call_path(date: OnCall::FIRST_VALID_DATE)
      end
      @date_range = date.all_month
      @on_calls_for_date = Hash.new {|hash, key| hash[key] = [] }

      # Add existing on-calls
      OnCall.where(date: @date_range, location: @location).each do |oc|
        @on_calls_for_date[oc.date][OnCall.shifts[oc.shift]] = oc
      end

      # Create new on-calls
      @date_range.each do |date|
        OnCall.shifts.values.each do |shift|
          @on_calls_for_date[date][shift] ||= OnCall.new(date: date, shift: shift, location: @location)
        end
      end
    end

    def on_call_params
      params.require(:on_call).permit(:date, :shift, :location)
    end

    def wrong_location_for_date
      date = params.fetch(:date, Date.current).to_date
      if date < ShiftTime::LOCATION_CHANGE_DATE
        ShiftTime::LOCATION_BEFORE != params[:location]
      else
        !ShiftTime::LOCATIONS_AFTER.include?(params[:location])
      end
    end
end
