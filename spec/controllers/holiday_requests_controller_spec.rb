require 'controllers/shared'

RSpec.describe HolidayRequestsController do

  before do
    HolidayRequest.create_any_not_present
  end

  describe "GET 'index'", autorequest: true, requires: :confirmed_current_user do
    let(:requests_for_current_user_location) do
      HolidayRequest.active.select {|hr| hr.location == current_user.location_for(hr.date) }
    end
    let(:expected_assigns) { { requests: contain_exactly(*requests_for_current_user_location) } }

    it "only includes shifts for the current user's location" do
    end
  end

end
