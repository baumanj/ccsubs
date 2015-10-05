require 'controllers/shared'

describe AvailabilitiesController do

  describe "GET 'index'", autorequest: true, requires: :login do
    it "returns http success" do
      get 'index'
      expect(response).to be_success
    end

  end
end
