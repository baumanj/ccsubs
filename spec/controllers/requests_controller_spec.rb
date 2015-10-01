require 'controllers/shared'

  # resources :users
  # get '/requests/fulfilled', to: 'requests#fulfilled', as: :fulfilled_requests
  # get '/requests/owned', to: 'requests#owned_index', as: :current_user_owned_requests
  # get '/requests/owned/:user_id', to: 'requests#owned_index', as: :owned_requests
  # resources :requests, except: [:edit]
  # get '/requests/:user_id/pending', to: 'requests#pending', as: :pending_requests
  # patch '/requests/:id/sub', to: 'requests#offer_sub', as: :offer_sub

describe RequestsController do

  ['index', 'fulfilled', 'owned_index', 'pending'].each do |action|
    describe "GET '#{action}'" do
      it_behaves_like "an action needing login"

      context "when logged in but unconfirmed" do
        include_context "logged in"
        it_behaves_like "an action needing user confirmation"
      end

      context "when logged in and confirmed" do
        include_context "logged in and confirmed"

        it "returns http success" do
          get 'index'
          expect(response).to be_success
        end
      end
    end
  end

  describe "GET 'index'" do
    it_behaves_like "an action needing login"

    context "when logged in but unconfirmed" do
      include_context "logged in"
      it_behaves_like "an action needing user confirmation"
    end

    context "when logged in and confirmed" do
      include_context "logged in and confirmed"

      it "returns http success" do
        get 'index'
        expect(response).to be_success
      end
    end

  end
end
