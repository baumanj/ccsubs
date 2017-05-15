require 'controllers/shared'

describe AvailabilitiesController do

  describe "POST 'create'", autorequest: true, requires: :login do
    let(:availability_attrs) { attributes_for(:availability, user_id: create(:user).id) }
    let(:params) do
      { availability: availability_attrs }
    end

    it "creates a new availability with the supplied parameters", rendered: nil do
      expect(Availability.find_by(availability_attrs)).to eq(Availability.last)
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

  describe "GET 'index'", autorequest: true, requires: :login do
    let(:expected_assigns) do
      { user: eq(subject.current_user),
        suggested_availabilities: be_an(Array) }
    end
  end

  describe "GET 'edit_default'", autorequest: true, requires: :login do
    let(:expected_assigns) do
      { user: eq(current_user),
        default_availabilities: be_any }
    end

    it "assigns @user and @default_availabilities" do
    end
  end

end
