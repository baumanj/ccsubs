class AvailabilitiesController < ApplicationController
  before_action :require_signin
  before_action :check_authorization, only: [:index]

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
    @user = if params[:id]
      User.find(params[:id])
    else
      current_user
    end
    @availabilities = @user.availabilities.where(request_id: nil).where("start > ?", DateTime.now).order(:start)
    @availability = Availability.new
  end

  def destroy
    availability = Availability.find(params[:id])
    if current_user_can_edit?(availability)
      availability.destroy
      flash[:success] = "Availability deleted"
    else
      flash[:error] = "You don't have permission to delete that"
    end
    redirect_to availabilities_path
  end

  private

    def availability_params
      params.require(:availability).permit(:start, :shift)
    end
end
