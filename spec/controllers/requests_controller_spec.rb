require 'controllers/shared'

shared_context "let request = @request", assigns: :request do
  let(:request) { assigns(:request) }
end

describe RequestsController do

  describe "GET 'new'", requires: :confirmed_current_user, assigns: :request do
    context "when logged in and confirmed" do
      include_context "logged in and confirmed"

      it "assigns @request to a new Request for the current user" do
        get 'new'
        expect(request).to be_a_new(Request)
        expect(request.user).to eq(subject.current_user)
      end
    end
  end

  describe "POST 'create'", requires: :confirmed_current_user, assigns: :request do

    it "saves a new Request for current_user" do
      expect(subject.current_user).to be_confirmed
      expect(subject.current_user).to_not be_admin
      post 'create', request: attributes_for(:request)
      expect(request).to be_persisted
      expect(request.user).to eq(subject.current_user)
      expect(response).to redirect_to(request)
    end

    it "fails to create a request for a different user" do
      other_user = create(:user)
      expect(other_user).to_not eq(subject.current_user)
      post 'create', request: attributes_for(:request).merge(user_id: other_user.id)
      expect(request).to be_persisted
      expect(request.user).to eq(subject.current_user)
      expect(response).to redirect_to(request)
    end

    context "when logged in as admin", login: :admin do # need rspec upgrade to put on example directly?
      it "can create a request for a different user" do
        expect(subject.current_user).to be_admin
        other_user = create(:user)
        expect(other_user).to_not eq(subject.current_user)
        post 'create', request: attributes_for(:request).merge(user_id: other_user.id)
        expect(request).to be_persisted
        expect(request.user).to eq(other_user)
        expect(response).to redirect_to(request)
      end
    end

    it "fails to create a duplicate request"
    it "fails to create a request in the past"
    it "fails to create a request more than a year from now"
  end

  describe "#show" do it end
  describe "#old_create" do it end
  describe "#update" do it end
  describe "#offer_sub" do it end

  describe "GET 'index'", requires: :confirmed_current_user do
    before { get 'index' }

    it "shows active requests" do
      expect(response).to be_success
      expect(assigns(:requests)).to eq(Request.active)
    end
  end

  describe "#owned_index" do it end
  describe "#fulfilled" do it end
  describe "#pending" do it end
  describe "#destroy" do it end
end
