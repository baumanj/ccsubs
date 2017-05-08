class OnCallsController < ApplicationController
  before_action :require_signin

  def index
    if current_user.staff_or_admin?
      set_date_range_and_on_calls
    else
      redirect_to edit_on_call_path(params[:date])
    end
  end

  def edit
    if current_user.staff_or_admin?
      redirect_to on_call_path(params[:date])
    else
      set_date_range_and_on_calls
    end
  end

  def create
    @on_call =
      OnCall.where(date: on_call_params[:date].to_date.all_month, user: current_user).first ||
      OnCall.new(user: current_user)

    if @on_call.update(on_call_params)
      flash[:success] = "On call for #{@on_call.date.strftime('%B')} saved"
      mailer.confirm_on_call_signup(@on_call).deliver_now
      redirect_to edit_on_call_path(@on_call.date)
    else
      @errors = @on_call.errors
      set_date_range_and_on_calls
      render 'edit' # Try again
    end
  end

  private

    def set_date_range_and_on_calls
      date = params.fetch(:date, Date.current).to_date
      if date < OnCall::FIRST_VALID_DATE
        date = OnCall::FIRST_VALID_DATE
        flash[:alert] = "Online on-call signup is not availble before #{OnCall::FIRST_VALID_DATE}"
        redirect_to on_call_path(OnCall::FIRST_VALID_DATE)
      end
      @date_range = date.all_month
      @on_calls_for_date = Hash.new {|hash, key| hash[key] = [] }

      # Add existing on-calls
      OnCall.where(date: @date_range).each do |oc|
        @on_calls_for_date[oc.date][OnCall.shifts[oc.shift]] = oc
      end

      # Create new on-calls
      @date_range.each do |date|
        OnCall.shifts.values.each do |shift|
          @on_calls_for_date[date][shift] ||= OnCall.new(date: date, shift: shift)
        end
      end
    end

    def on_call_params
      params.require(:on_call).permit(:date, :shift)
    end

end
