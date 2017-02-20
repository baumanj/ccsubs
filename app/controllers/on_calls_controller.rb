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
    set_date_range_and_on_calls
  end

  def create
    @on_call = OnCall.new(on_call_params.merge(user: current_user))

    if @on_call.valid?
      OnCall.destroy_all(user: @on_call.user, date: @on_call.date.all_month)
      @on_call.save!
      flash[:success] = "On call for #{@on_call.date.strftime('%B')} saved"
      redirect_to edit_on_call_path(@on_call.date)
    else
      @errors = @on_call.errors
      set_date_range_and_on_calls
      render 'edit' # Try again
    end
  end

  private

    def set_date_range_and_on_calls
      @date_range = params.fetch(:date, Date.current).to_date.all_month
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
