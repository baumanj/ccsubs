class AvailabilitiesController < ApplicationController
  before_action :require_signin

  def create
    @availability = Availability.new(availability_params)
    @availability.user = current_user
    if @availability.save
      flash[:success] = "Availability added"
      redirect_to availabilities_path
    else
      @errors = @availability.errors
      render 'new' # Try again
    end
  end

  def index
    @availabilities = current_user.future_availabilities
    @availability = Availability.new
    @user = current_user
    unique_shift_requests = Request.all_seeking_offers.uniq {|r| r.start }
    @suggested_availabilities = unique_shift_requests.map do |r|
      unless r.user == current_user || current_user.availability_known?(r)
        Availability.new(date: r.date, shift: r.shift)
      end
    end.compact
  end

  def destroy
    availability = Availability.find(params[:id])
    if availability.request
      flash[:error] = "This availability is committed to #{availability.request.user}'s request, so it can't be deleted."
    elsif current_user_can_edit?(availability)
      availability.destroy
      flash[:success] = "Availability deleted"
    else
      flash[:error] = "You don't have permission to delete that"
    end
    redirect_to availabilities_path
  end

  private

    def availability_params
      params.require(:availability).permit(:date, :shift)
    end
end
