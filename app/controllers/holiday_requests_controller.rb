class HolidayRequestsController < ApplicationController
  before_action :require_confirmed_email

  def index
    location = current_user.location
    @requests = HolidayRequest.where(location: location).active
  end
end
