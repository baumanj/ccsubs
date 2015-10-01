require 'controllers/shared_spec'

describe AvailabilitiesController do

  describe "GET 'index'" do
    it_behaves_like "an action needing login"

    context "when logged in" do
      include_context "logged in"

      it "returns http success" do
        get 'index'
        expect(response).to be_success
      end
    end

  end
end
