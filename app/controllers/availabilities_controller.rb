class AvailabilitiesController < ApplicationController
  before_action :require_signin

  def create
    availability = Availability.new(availability_params)
    if availability.save
      flash[:success] = "#{availability.free? ? "A" : "Una"}vailability for #{availability} added"
    else
      flash[:error] = "Something went awry adding unavailability"
    end
    redirect_to :back
  end

  def update
    @availability = Availability.find(params[:id])

    if current_user_can_edit?(@availability) && @availability.update!(free_param)
      flash[:success] = "Availability updated"
    else
      flash[:error] = "Only the request owner can do that."
    end

    redirect_to :back
  end

  def index
    @user = current_user
    @suggested_availabilities = DefaultAvailability.apply(@user.suggested_availabilities)
  end

  def edit_default
    @user = current_user
    @default_availabilities = DefaultAvailability.find_for_edit(@user)
  end

  private

    def availability_params
      params.require(:availability).permit(:user_id, :date, :shift, :free)
    end

    def free_param
      params.require(:availability).permit(:free)
    end

end