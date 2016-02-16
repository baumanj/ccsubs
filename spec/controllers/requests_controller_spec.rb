require 'controllers/shared'

shared_context "receivable_request", create: :receivable_request do
  let(:receivable_request) do
    create(:request,
      user: create(:availability, date: ask.date, shift: ask.shift).user)
  end
end

shared_context "expect request to be saved", expect: :request_saved do
  # changed? implies unsaved; see ActiveModel::Dirty
  after { expect(assigns[:request]).to_not be_changed }
end

describe RequestsController do

  request_types = [
    :seeking_offers_request,
    :sent_offer_request,
    :received_offer_request,
    :fulfilled_request
  ]
  past_request_types = request_types.map {|rt| :"past_#{rt}" }

  describe "GET 'new'", autorequest: true, requires: :confirmed_current_user do
    let(:expected_assigns) { { request: be_a_new(Request) } }

    context "when passed 'date' and 'shift' params" do
      let(:params) { attributes_for(:request).slice(:date, :shift) }

      it "assigns them to @request" do
        expect(assigns(:request).date).to eq(params[:date])
        expect(assigns(:request).shift).to eq(params[:shift])
      end
    end
  end

  describe "POST 'create'", autorequest: true, requires: :confirmed_current_user do
    let(:request_params) { attributes_for(:request) }
    let(:params) { { request: request_params } }
    let(:expected_assigns) { { request: be_a(Request) } }

    it "fails to save a duplicate request", rendered: nil do
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
        expect(assigns(:request).errors).to_not be_empty
        # puts assigns(:request).errors.full_messages.join
      end
    end

    context "when successful" do
      before do
        expect(assigns(:request)).to be_persisted
        expect(response).to redirect_to(assigns(:request))
      end

      it "saves a new Request for current_user" do
        expect(assigns(:request).user).to eq(subject.current_user)
      end

      context "with request[user_id] in params" do
        let(:specified_user) { create(:user) }
        let(:params) { { request: attributes_for(:request).merge(user_id: specified_user.id) } }
        let(:expected_assigns) { { request: be_persisted } }

        before { expect(specified_user).to_not eq(subject.current_user) }

        it "fails to create a request for a different user" do
          expect(assigns(:request).user).to eq(subject.current_user)
        end

        it "can create a request for a different user", login: :admin do
          expect(assigns(:request).user).to eq(specified_user)
        end
      end
    end

    context "when date is in the past", expect: :flash_error do
      let(:request_params) { attributes_for(:request, date: Faker::Date.backward) }
      it_behaves_like "a request with invalid parameters"
    end

    context "when date is more than a year in the future", expect: :flash_error do
      let(:request_params) { attributes_for(:request, date: Faker::Date.between(1.year.from_now, 10.years.from_now)) }
      it_behaves_like "a request with invalid parameters"
    end
  end

  describe "GET 'show'", autorequest: true, requires: :confirmed_current_user do
    let(:ask) { create(:request) }
    let(:params) { { id: ask.id } }
    let(:expected_assigns) do
      { request: eq(ask),
        requests_to_swap_with: be_empty
      }
    end

    shared_examples "an action that just finds the request record" do
      it "finds the request record and renders 'show'" do
        expect(assigns).to contain_exactly(
          ["_optimized_routes", true],
          ["request", ask],
          ["current_user", subject.current_user],
          ["marked_for_same_origin_verification", true])
      end
    end

    context "when request belongs to current_user" do
      let(:ask) { create(:request, user: current_user) }

      it "belongs to current_user" do
        expect(assigns[:request].user).to eq(subject.current_user)
      end

      context "when request can send a swap offer", create: :receivable_request do

        let(:evaluate_before_http_request) { receivable_request }
        let(:rendered_template) { 'choose_swap' }
        let(:expected_assigns) do
          { request: eq(ask),
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
              create(:availability, free: false, date: ask.date, shift: ask.shift)
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
          { request: eq(ask),
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
        let(:ask) { create(:received_offer_request, user: current_user) }
        it_behaves_like "an action that just finds the request record"
      end

      context "when request state is sent_offer" do
        let(:ask) { create(:sent_offer_request, user: current_user) }
        it_behaves_like "an action that just finds the request record"
      end

      context "when request state is fulfilled" do
        let(:ask) { create(:fulfilled_request, user: current_user) }
        it_behaves_like "an action that just finds the request record"
      end
    end

    context "when request does not belong to current_user" do
      it "does not belong to current_user" do
        expect(assigns[:request].user).to_not eq(subject.current_user)
      end

      context "when request can recieve a swap offer from current_user" do
        let(:current_user_request) { create(:request, user: current_user) }
        let(:ask) do
          create(:request,
            user: create(:availability, date: current_user_request.date, shift: current_user_request.shift).user)
        end
        let(:expected_assigns) do
          { request: eq(ask),
            requests_to_swap_with: contain_exactly(current_user_request),
            availabilities_for_requests_to_swap_with: be_any }
        end

        it "lets the current_user choose which of their requests to offer as a swap" do
          availabilities = assigns[:availabilities_for_requests_to_swap_with]
          expect(availabilities.size).to eq(1)
          expect(availabilities.first.start).to eq(current_user_request.start)
        end
      end

      context "when request state is received_offer" do
        let(:ask) { create(:received_offer_request) }
        it_behaves_like "an action that just finds the request record"
      end

      context "when request state is sent_offer" do
        let(:ask) { create(:sent_offer_request) }
        it_behaves_like "an action that just finds the request record"
      end

      context "when request state is fulfilled" do
        let(:ask) { create(:fulfilled_request) }
        it_behaves_like "an action that just finds the request record"
      end
    end
  end

  describe "PATCH 'update'", autorequest: true, requires: :confirmed_current_user do
    let(:ask) { create(:request) }
    let(:params) { { id: ask.id } }
    let(:expected_assigns) { { request: eq(ask) } }

    it "must be owned by the user", expect: :flash_error, rendered: nil do
      expect(response).to redirect_to(request_url(ask))
    end

    context "when updating request_to_swap_with_id", create: :receivable_request do
      let(:ask) { create(:request, user: current_user) }
      let(:params) do
        { id: ask.id,
          request_to_swap_with_id: receivable_request.id
        }
      end

      context "when request to swap with is deleted" do
        let(:evaluate_before_http_request) { receivable_request.destroy! }
        it "fails", expect: :flash_error, rendered: nil do
          expect(assigns(:request)).to be_seeking_offers
        end
      end

      context "when request is seeking_offers" do
        let(:rendered_template) { "user_mailer/notify_swap_offer" }

        it "sends an offer", expect: :request_saved do
          expect(assigns(:request)).to be_sent_offer
          expect(assigns(:request).fulfilling_swap).to eq(receivable_request)
          expect(assigns(:request).fulfilling_swap).to be_received_offer
        end
      end

      [:received_offer_request, :sent_offer_request, :fulfilled_request].each do |request_type|
        context "when request is #{request_type}" do
          let(:ask) { create(request_type, user: current_user) }
          let(:original_request_state) { ask.state }
          let(:evaluate_before_http_request) { original_request_state }

          it "doesn't send an offer", expect: :flash_error do
            unless assigns(:request).changed? # (i.e., not saved)
              expect(assigns(:request).state).to eq(original_request_state)
              expect(assigns(:request).fulfilling_swap).to_not eq(receivable_request)
            end
          end
        end
      end
    end

    context "when responding to offer", expect: :request_saved do
      let(:ask) { create(:received_offer_request, user: current_user) }
      let(:params) do
        { id: ask.id,
          offer_response: offer_response
        }
      end
      let(:request_that_sent_the_offer) { ask.fulfilling_swap }
      let(:evaluate_before_http_request) { request_that_sent_the_offer }

      context "when 'offer_response' is 'accept'" do
        let(:offer_response) { :accept }
        let(:rendered_templates) { ["user_mailer/notify_swap_accept", "user_mailer/remind_swap_accept"] }

        it "sets the requests states to 'fulfilled' and sends nofitication" do
          [assigns(:request), request_that_sent_the_offer.reload].each do |r|
            expect(r).to be_fulfilled
          end
        end
      end

      context "when 'offer_response' is 'decline'" do
        let(:offer_response) { :decline }
        let(:rendered_template) { "user_mailer/notify_swap_decline" }

        it "sets the requests states to 'seeking_offers' and sends nofitication" do
          [assigns(:request), request_that_sent_the_offer.reload].each do |r|
            expect(r).to be_seeking_offers
          end
        end
      end

      [:seeking_offers_request, :sent_offer_request, :fulfilled_request].each do |request_type|
        context "when request is #{request_type}" do
          let(:ask) { create(request_type, user: current_user) }
          let(:original_request_state) { ask.state }

          [:accept, :decline].each do |offer_response_value|
            context "when offer_response is #{offer_response_value}" do
              let(:offer_response) { offer_response_value }

              it "displays an error and doesn't change the request", expect: :flash_error do
                expect(assigns(:request).state).to eq(original_request_state)
              end
            end
          end
        end
      end
    end
  end

  describe "PATCH 'offer_sub'", autorequest: true, requires: :confirmed_current_user do
    let(:ask) { create(:request) }
    let(:params) { { id: ask.id } }
    let(:expected_assigns) { { request: eq(ask) } }

    context "when request is seeking_offers", expect: :request_saved do
      let(:ask) { create(:seeking_offers_request) }
      let(:rendered_templates) { ["user_mailer/notify_sub", "user_mailer/remind_sub"] }
      it "sets the request state to 'fulfilled' and sends nofitication" do
        expect(assigns(:request)).to be_fulfilled
      end
    end

    [:sent_offer_request, :received_offer_request, :fulfilled_request].each do |request_type|
      context "when request is #{request_type}" do
        let(:ask) { create(request_type) }
        let(:original_request_state) { ask.state }

        it "displays an error and doesn't change the request", expect: :flash_error do
          expect(assigns(:request).state).to eq(original_request_state)
        end
      end
    end

    context "when the subber doesn't have the availability" do
      let(:ask) { create(:seeking_offers_request) }
      let(:evaluate_before_http_request) do
        create(:availability, user: current_user, free: false, date: ask.date, shift: ask.shift)
      end

      it "displays an error and doesn't fulfill the request", expect: :flash_error do
        expect(assigns(:request)).to be_seeking_offers
      end
    end
  end

  describe "GET 'index'", autorequest: true, requires: :confirmed_current_user do
    let(:expected_assigns) { { requests: eq(Request.active) } }

    it "sets @requests to active requests" do
    end
  end

  describe "GET 'owned_index'", autorequest: true, requires: :confirmed_current_user do
    let(:expected_assigns) do
      { owner: eq(current_user),
        requests: match_array(expected_requests) }
    end
    let(:expected_requests) do
      request_types.shuffle.map do |type|
        create(type, user: current_user)
      end
    end
    let(:excluded_requests) do
      create(request_types.sample) # not belonging to user
      create(past_request_types.sample, user: current_user)
    end
    let(:evaluate_before_http_request) { expected_requests; excluded_requests }

    it "sets @requests to all requests on or after today" do
      expect(assigns(:requests).size).to be > 1
    end
  end

  describe "GET 'fulfilled'", autorequest: true, requires: :login do
    let(:expected_assigns) do
      { requests: match_array(expected_requests),
        today: match_array(todays_requests),
        this_week: match_array(this_weeks_requests),
        later: match_array(later_requests)
      }
    end

    let(:todays_requests) do
      Array.new(rand(10)) { create(:fulfilled_request) }
    end

    let(:this_weeks_requests) do
      Array.new(rand(10)) do
        create(:fulfilled_request,
               date: Faker::Date.between(1.day.from_now, 1.week.from_now))
      end
    end

    let(:later_requests) do
      Array.new(rand(10)) do
        create(:fulfilled_request,
               date: Faker::Date.between(8.days.from_now, 1.year.from_now))
      end
    end

    let(:expected_requests) do
      todays_requests + this_weeks_requests + later_requests
    end

    let(:evaluate_before_http_request) do
      unfulfilled_request_types =
        request_types.reject {|t| t == :fulfilled_request} +
        past_request_types.reject {|t| t == :past_fulfilled_request }
      rand(100).times { create(unfulfilled_request_types.sample) }
    end

    it "assigns all instance variables correctly" do
    end
  end

  describe "GET 'pending'", autorequest: true, requires: :confirmed_current_user do
    let(:expected_assigns) do
      { requests: match_array(pending_requests) }
    end

    let(:pending_requests) do
      # Create 2 to 4 pending requests
      Array.new(2 + rand(3)) do
        create(:received_offer_request, user: current_user)
      end
    end

    let(:non_pending_requests) do
      # Requests from the user, but which are not pending
      non_pending_request_types =
        request_types.reject {|t| t == :received_offer_request} +
        past_request_types
      rand(10).times { create(non_pending_request_types.sample, user: current_user) }

      # Requests from other users
      rand(10).times { create((request_types + past_request_types).sample) }
    end

    let(:evaluate_before_http_request) do
      pending_requests
      non_pending_requests
    end

    it "assigns instance variables correctly" do
    end

    context "when only one pending request" do
      let(:pending_requests) do
        [create(:received_offer_request, user: current_user)]
      end

      it "redirects to the pending request" do
        expect(response).to redirect_to(pending_requests.first)
      end
    end
  end

  describe "DELETE 'destroy'", autorequest: true, requires: :confirmed_current_user do
    let(:ask) { create(:request) }
    let(:params) { { id: ask.id } }
    let(:expected_assigns) { { request: eq(ask) } }

    context "when seeking_offers" do
      context "when the current_user is the request owner" do
        let(:ask) { create(:seeking_offers_request, user: current_user) }

        it "removes the request record" do
          expect(assigns[:request]).to be_destroyed
        end
      end
    end

    request_types.each do |request_type|
      if request_type == :seeking_offers_request

        context "when the current_user is the request owner" do
          let(:ask) { create(request_type, user: current_user) }

          it "removes the request record" do
            expect(assigns[:request]).to be_destroyed
          end
        end

        context "when the current_user is an admin", requires: :admin do
          let(:ask) { create(request_type, user: current_user) }

          it "removes the request record" do
            expect(assigns[:request]).to be_destroyed
          end
        end

        context "when the current user is neither the owner nor an admin", expect: :flash_error do
          it "doesn't remove request record" do
            expect(ask).to be_persisted
          end
        end

      else
        context "when the request is a #{request_type}", expect: :flash_error do
          let(:ask) { create(request_type, user: current_user) }

          it "doesn't remove request record" do
            expect(ask).to be_persisted
          end
        end
      end
    end

    past_request_types.each do |past_request_type|
      context "when the request is a #{past_request_type}", expect: :flash_error do
        let(:ask) { create(past_request_type, user: current_user) }

        it "doesn't remove request record" do
          expect(ask).to be_persisted
        end
      end
    end

  end

end
