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
    let(:request_params) { attributes_for(:request) }
    let(:params) { { request: request_params } }

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

    it "fails to save a duplicate request" do
      post 'create', params
      duplicate_request = assigns(:request)
      expect(duplicate_request).to_not be_persisted
      expect(duplicate_request.errors).to_not be_empty
      expect(response).to render_template(:new)
    end

    shared_examples "a request with invalid parameters" do
      it "fails to save" do
        expect(request.errors).to_not be_empty
        # puts request.errors.full_messages.join
        expect(response).to render_template(:new)
      end
    end

    context "when date is in the past" do
      let(:request_params) { attributes_for(:request, date: Faker::Date.backward) }
      it_behaves_like "a request with invalid parameters"
    end

    context "when date is more than a year in the future" do
      let(:request_params) { attributes_for(:request, date: Faker::Date.between(1.year.from_now, 10.years.from_now)) }
      it_behaves_like "a request with invalid parameters"
    end
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
