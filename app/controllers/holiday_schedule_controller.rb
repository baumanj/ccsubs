class HolidayScheduleController < ApplicationController
  before_action :require_staff_or_admin

  def index
    @dates = Holiday::NAMES.map {|n| Holiday.next_date(n) }.sort
    @requests = HolidayRequest.on_or_after(Date.current)
  end
end
