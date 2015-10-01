require 'controllers/shared_spec'

describe AvailabilitiesController do

  describe "GET 'index'" do
    it "redirects to signin" do
      get 'index'
      expect(response).to redirect_to(signin_url)
    end

    context "when logged in" do
      include_context "logged in"
      # before { current_user = create(:user) }
      it "succeeds" do
        expect(response).to be_ok
      end
    end
  end
end
