require 'controllers/shared'

describe RequestsController do
  let(:request) { assigns(:request) }

  describe "GET 'new'", autorequest: true, requires: :confirmed_current_user do
    let(:expected_assigns) { { request: be_a_new(Request) } }
    it "assigns @request to a new Request for the current user" do
      expect(request.user).to eq(subject.current_user)
      expect(response).to be_success
    end
  end

  describe "POST 'create'", autorequest: true, requires: :confirmed_current_user do
    let(:request_params) { attributes_for(:request) }
    let(:params) { { request: request_params } }
    let(:expected_assigns) { { request: be_a_new(Request) } }

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
        let(:expected_assigns) do
          { request: be_a_new(Request),
            errors: be_any }
        end

        before { expect(specified_user).to_not eq(subject.current_user) }

        it "fails to create a request for a different user" do
          expect(request.user).to eq(subject.current_user)
        end

        it "can create a request for a different user", login: :admin do
          expect(request.user).to eq(specified_user)
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
      let(:rendered_template) { 'new' }
      let(:expected_assigns) do
        { request: be_a_new(Request),
          errors: be_any }
      end

      it "fails to save" do
        expect(request.errors).to_not be_empty
        # puts request.errors.full_messages.join
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
    let(:expected_assigns) do
      { request: eq(request),
        requests_to_swap_with: be_empty
      }
    end

    shared_examples "an action that just finds the request record" do
      it "finds the request record and renders 'show'" do
        expect(assigns).to contain_exactly(
          ["request", request],
          ["current_user", subject.current_user],
          ["marked_for_same_origin_verification", true])
      end
    end

    context "when request belongs to current_user" do
      let(:request) { create(:request, user: user) }

      it "belongs to current_user" do
        expect(assigns[:request].user).to eq(subject.current_user)
      end

      context "when request can send a swap offer" do
        let(:receivable_request) do
          create(:request,
            user: create(:availability, date: request.date, shift: request.shift).user)
        end
        let(:evaluate_before_http_request) { receivable_request }
        let(:rendered_template) { 'choose_swap' }
        let(:expected_assigns) do
          { request: eq(request),
            requests_to_swap_with: contain_exactly(receivable_request),
            availabilities_for_requests_to_swap_with: be_any }
        end

        it "lets the current_user choose which request to offfer a swap to" do
          expect(assigns[:availabilities_for_requests_to_swap_with].size).to eq(1)
          expect(assigns[:availabilities_for_requests_to_swap_with].first.start).to eq(receivable_request.start)
        end
      end

      context "when there are potential matches" do
        let(:potential_match_request) { create(:request) }
        let(:nonmatching_requests) do
          [ create(:request, user:
              create(:availability, free: false, date: request.date, shift: request.shift)
                .user),
            create(:sent_offer_request),
            create(:received_offer_request),
            create(:fulfilled_request)
          ]
        end
        let(:evaluate_before_http_request) do
          potential_match_request
          nonmatching_requests
        end
        let(:rendered_template) { 'specify_availability' }
        let(:expected_assigns) do
          { request: eq(request),
            requests_to_swap_with: be_empty,
            suggested_availabilities: be_any }
        end

        it "lets the current_user specify their availability for the potential matches" do
          expect(assigns[:suggested_availabilities].size).to eq(1)
          expect(assigns[:suggested_availabilities].first.start).to eq(potential_match_request.start)
        end
      end

      context "when there are no potential matches" do
        it "doesn't allow the user to offer swaps or specify availability" do
          expect(assigns).to_not include(:availabilities_for_requests_to_swap_with)
          expect(assigns).to_not include(:suggested_availabilities)
        end
      end

      context "when request state is received_offer" do
        let(:request) { create(:received_offer_request, user: user) }
        it_behaves_like "an action that just finds the request record"
      end

      context "when request state is sent_offer" do
        let(:request) { create(:sent_offer_request, user: user) }
        it_behaves_like "an action that just finds the request record"
      end

      context "when request state is fulfilled" do
        let(:request) { create(:fulfilled_request, user: user) }
        it_behaves_like "an action that just finds the request record"
      end
    end

    context "when request does not belong to current_user" do
      it "does not belong to current_user" do
        expect(assigns[:request].user).to_not eq(subject.current_user)
      end

      context "when request can recieve a swap offer from current_user" do
        let(:current_user_request) { create(:request, user: user) }
        let(:request) do
          create(:request,
            user: create(:availability, date: current_user_request.date, shift: current_user_request.shift).user)
        end
        let(:expected_assigns) do
          { request: eq(request),
            requests_to_swap_with: contain_exactly(request),
            availabilities_for_requests_to_swap_with: be_any }
        end

        it "lets the current_user choose which of their request to offer as a swap" do
          expect(assigns[:availabilities_for_requests_to_swap_with].size).to eq(1)
          expect(assigns[:availabilities_for_requests_to_swap_with].first.start).to eq(request.start)
        end
      end

      context "when request state is received_offer" do
        let(:request) { create(:received_offer_request) }
        it_behaves_like "an action that just finds the request record"
      end

      context "when request state is sent_offer" do
        let(:request) { create(:sent_offer_request) }
        it_behaves_like "an action that just finds the request record"
      end

      context "when request state is fulfilled" do
        let(:request) { create(:fulfilled_request) }
        it_behaves_like "an action that just finds the request record"
      end
    end
  end

  describe "#old_create" do it end
  describe "#update" do it end
  describe "#offer_sub" do it end

  describe "GET 'index'", autorequest: true, requires: :confirmed_current_user do
    let(:expected_assigns) { { requests: eq(Request.active) } }

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
