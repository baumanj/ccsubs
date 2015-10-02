require 'controllers/shared'


describe RequestsController do

  ['index', 'fulfilled', 'owned_index'].each do |action|
    describe "GET '#{action}'" do
      it_behaves_like "an action needing login"

      context "when logged in but unconfirmed" do
        include_context "logged in"
        it_behaves_like "an action needing user confirmation"
      end

      context "when logged in and confirmed" do
        include_context "logged in and confirmed"

        it "returns http success" do
          get action
          expect(response).to be_success
        end
      end
    end
  end

  describe "#new" do it end
  describe "#create" do it end
  describe "#show" do it end
  describe "#old_create" do it end
  describe "#update" do it end
  describe "#offer_sub" do it end

  describe "#index" do
    include_context "logged in and confirmed"
    before { get 'index' }

    it "shows active requests" do
      expect(assigns(:requests)).to eq(Request.active)
    end
  end

  describe "#owned_index" do it end
  describe "#fulfilled" do it end
  describe "#pending" do it end
  describe "#destroy" do it end
end
