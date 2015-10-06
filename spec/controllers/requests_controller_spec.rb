require 'controllers/shared'

describe RequestsController do
  let(:request) { assigns(:request) }

  describe "GET 'new'", autorequest: true, requires: :confirmed_current_user do
    it "assigns @request to a new Request for the current user" do
      expect(request).to be_a_new(Request)
      expect(request.user).to eq(subject.current_user)
      expect(response).to be_success
    end
  end

  describe "POST 'create'", autorequest: true, requires: :confirmed_current_user do
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

  describe "GET 'show'", autorequest: true, requires: :confirmed_current_user do
    let(:request) { create(:request) }
    let(:params) { { id: request.id } }

    shared_examples "a request with no swap options" do
      it "assigns empty @requests_to_swap_with and @availabilities_for_requests_to_swap_with" do
        expect(assigns[:requests_to_swap_with]).to be_empty
        expect(assigns[:availabilities_for_requests_to_swap_with]).to be_nil
        expect(request).to_not be_nil
        expect(response).to be_success
      end
    end

    context "when there are no swap options" do
      it_behaves_like "a request with no swap options"

      it "does not belong to the current_user" do
        expect(request.user).to_not eq(subject.current_user)
      end
    end

    context "when showing current_user's request" do
      let(:request) { create(:request, user: user) }
      it_behaves_like "a request with no swap options"

      it "belongs to the current_user" do
        expect(request.user).to eq(subject.current_user)
      end

      context "when this request can be offered as a swap" do
        let(:evaluate_before_http_request) { receivable_request }
        let(:receivable_request) do
          create(:request,
            user: create(:availability, date: request.date, shift: request.shift).user)
        end

        it "has receivable_request in @requests_to_swap_with" do
          expect(assigns[:requests_to_swap_with]).to eq([receivable_request])
          expect(assigns[:availabilities_for_requests_to_swap_with]).to_not be_empty
          expect(response).to render_template(:choose_swap)
        end
      end

      context "when there are any potential matches" do
      end
    end
  end

  describe "#old_create" do it end
  describe "#update" do it end
  describe "#offer_sub" do it end

  describe "GET 'index'", autorequest: true, requires: :confirmed_current_user do
    it "sets @requests to active requests" do
      expect(response).to be_success
      expect(assigns(:requests)).to eq(Request.active)
    end
  end

  describe "#owned_index" do it end
  describe "#fulfilled" do it end
  describe "#pending" do it end
  describe "#destroy" do it end
end
