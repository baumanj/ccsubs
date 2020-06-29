class HolidayRequestsController < ApplicationController
  before_action :require_confirmed_email

  def index
    @requests = HolidayRequest.active.select do |r|
      r.location == current_user.location_for(r.date)
    end
  end
end
