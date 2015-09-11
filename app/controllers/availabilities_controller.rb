class AvailabilitiesController < ApplicationController
  before_action :require_signin

  def create
    if params['commit'] == "No"
      @unavailability = Unavailability.new(availability_params)
      if @unavailability.save
        flash[:success] = "Unavailability for #{@unavailability} added"
        redirect_to :back
      else
        flash[:error] = "Something went awry adding unavailability"
      end
    else
      @availability = Availability.new(availability_params)
      Availability.transaction do
        destroyed = Unavailability.destroy_all(availability_params)
        if @availability.save
          flash[:success] = "Availability for #{@availability} added"
          flash[:success] += " (and corresponding unavailability removed)" if destroyed.any?
          redirect_to :back
        else
          @errors = @availability.errors
          render '_new' # Try again
        end
      end
    end
  end

  def index
    @availabilities = current_user.future(:availabilities)
    @unavailabilities = current_user.future(:unavailabilities)
    @availability = Availability.new
    @user = current_user
    unique_shift_requests = Request.all_seeking_offers.uniq {|r| r.start }
    @suggested_availabilities = @user.suggested_availabilities
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
    redirect_to :back
  end

  private

    def availability_params
      p = params.require(:availability).permit(:date, :shift)
      p.update(shift: ShiftTime::SHIFT_NAMES.find_index(p[:shift]) || p[:shift],
        user_id: current_user.id)
    end
end
