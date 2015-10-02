require 'controllers/shared'

shared_context "let request = @request", assigns: :request do
  let(:request) { assigns(:request) }
end

describe RequestsController do

  describe "GET 'new'", requires: :confirmed_current_user, assigns: :request do
    context "when logged in and confirmed" do
      include_context "logged in and confirmed"
      before { get 'new' }

      it "assigns @request to a new Request for the current user" do
        expect(request).to be_a_new(Request)
        expect(request.user).to eq(subject.current_user)
      end
    end
  end

  describe "POST 'create'", requires: :confirmed_current_user, assigns: :request do
    context "when logged in and confirmed" do
      include_context "logged in and confirmed"

      it "saves a new Request for current_user" do
        post 'create', request: attributes_for(:request)
        expect(request).to be_persisted
        expect(request.user).to eq(subject.current_user)
        # byebug
        expect(response).to redirect_to(request)
      end
    end
  end

  describe "#show" do it end
  describe "#old_create" do it end
  describe "#update" do it end
  describe "#offer_sub" do it end

  describe "GET 'index'", requires: :confirmed_current_user do
    context "when logged in and confirmed" do
      include_context "logged in and confirmed"
      before { get 'index' }

      it "shows active requests" do
        expect(response).to be_success
        expect(assigns(:requests)).to eq(Request.active)
      end
    end
  end

  describe "#owned_index" do it end
  describe "#fulfilled" do it end
  describe "#pending" do it end
  describe "#destroy" do it end
end
