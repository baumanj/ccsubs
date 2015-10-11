require 'controllers/shared'

describe AvailabilitiesController do

  describe "GET 'index'", autorequest: true, requires: :login do
    let(:expected_assigns) do
      { user: eq(subject.current_user),
        suggested_availabilities: be_an(Array) }
    end
  end
end
