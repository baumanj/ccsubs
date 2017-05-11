require 'controllers/shared'

describe AvailabilitiesController do

  describe "GET 'index'", autorequest: true, requires: :login do
    let(:expected_assigns) do
      { user: eq(subject.current_user),
        suggested_availabilities: be_an(Array) }
    end
  end

  describe "PATCH 'update'", autorequest: true, requires: :login do
    let(:availability) { create(:availability) }
    let(:params) { { id: availability.id } }
    let(:expected_assigns) { { availability: eq(availability) } }

    it "must be owned by the user", expect: :flash_error, rendered: nil do
    end

    context "when updating the availability" do
      let(:availability) { create(:availability, user: current_user, free: false) }
      let(:params) do
        { id: availability.id,
          availability: { free: !availability.free } }
      end

      it "must update the free attribute" do
        expect(assigns(:availability)).to be_persisted
        expect(assigns(:availability).free).to eq(params[:availability][:free])
      end
    end

  end
end
