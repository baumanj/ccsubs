require 'controllers/shared'

shared_context "let request = @request", assigns: :request do
  let(:request) { assigns(:request) }
end

describe RequestsController do

  describe "GET 'new'", autorequest: true, requires: :confirmed_current_user, assigns: :request do
    it "assigns @request to a new Request for the current user" do
      expect(request).to be_a_new(Request)
      expect(request.user).to eq(subject.current_user)
      expect(response).to be_success
    end
  end

  describe "POST 'create'", autorequest: true, requires: :confirmed_current_user, assigns: :request do
    let(:params) { { request: attributes_for(:request) } }

    context "when successful" do
      before do
        expect(request).to be_persisted
        expect(response).to redirect_to(request)
      end

      it "saves a new Request for current_user" do
        expect(request.user).to eq(subject.current_user)
      end

      context "with request[user_id] in params" do
        let(:specified_user) { create(:user) }
        let(:params) { { request: attributes_for(:request).merge(user_id: specified_user.id) } }
        before { expect(specified_user).to_not eq(subject.current_user) }

        it "fails to create a request for a different user" do
          expect(request.user).to eq(subject.current_user)
        end

        context "when logged in as admin", login: :admin do # need rspec upgrade to put on example directly?
          it "can create a request for a different user" do
            expect(request.user).to eq(specified_user)
          end
        end
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

  describe "GET 'index'", autorequest: true, requires: :confirmed_current_user do

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
