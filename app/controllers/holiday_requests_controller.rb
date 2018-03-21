class HolidayRequestsController < ApplicationController
  before_action :require_confirmed_email

  def index
    @requests = HolidayRequest.active
  end
end
