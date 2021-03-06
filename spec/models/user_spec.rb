require 'spec_helper'

describe User do
  before do
    @user = create(:user)
  end

  it "has a valid factory" do
    expect(create(:user)).to be_valid
  end

  subject { @user }

  it { should respond_to(:name) }
  it { should respond_to(:email) }
  it { should respond_to(:password) }
  it { should respond_to(:password_confirmation) }
  it { should respond_to(:password_digest) }
  it { should respond_to(:authenticate) }

  it { should be_valid }
  it { should_not be_confirmed }

  describe "when correctly confirmed" do
    subject { create(:confirmed_user) }
    it { should be_confirmed }
  end

  describe "when incorrectly confirmed" do
    before do
      expect(subject.confirm(Faker::Internet.password)).to be_falsey
    end
    it { should_not be_confirmed }
  end

  describe "when password is not present" do
    before do
      @user = User.new(name: "Example User", email: "user@example.com",
                       password: " ", password_confirmation: " ")
    end
    it { should_not be_valid }
  end

  describe "when password doesn't match confirmation" do
    before { @user.password_confirmation = "mismatch" }
    it { should_not be_valid }
  end

  describe "with a password that's too short" do
    minimum_length = described_class.validators_on(:password)
      .find {|v| v.kind == :length && v.options.include?(:minimum) }
      .options[:minimum]
    before { @user.password = @user.password_confirmation = "a" * (minimum_length - 1) }
    it { should be_invalid }
  end

  describe "return value of authenticate method" do
    before { @user.save }
    let(:found_user) { User.find_by(email: @user.email) }

    describe "with valid password" do
      it { should eq found_user.authenticate(@user.password) }
    end

    describe "with invalid password" do
      let(:user_for_invalid_password) { found_user.authenticate("invalid") }

      it { should_not eq user_for_invalid_password }
      specify { expect(user_for_invalid_password).to eq(false) }
    end
  end

  describe "when no phone number is provided for a new user" do
    before do
      @user = build(:user, cell_phone: nil, home_phone: nil)
    end
    it { should be_invalid }
  end

  describe "when no phone number is provided for an exising user" do
    before do
      @user = create(:user)
      @user.cell_phone = nil
      @user.home_phone = nil
    end
    it { should be_valid }
  end

  it "logs in and out correctly"

  it "has potential to cover for shifts without conficts or availability" do
    request = create(:request)
    user = create(:user, location: request.location)
    preloaded_requests = [request]
    preloaded_availabilities = []

    expect(user.availability_state_for(request, preloaded_requests, preloaded_availabilities)).to eq(:potential)
  end

  it "returns Northgate location before the change date" do
    User.locations.keys.each do |location|
      user = create(:user, location: location)
      expect(user.location_for(ShiftTime::LOCATION_CHANGE_DATE.prev_day)).to eq(ShiftTime::LOCATION_BEFORE)
    end
  end

  it "returns Belltown location before the Renton opening date" do
    User.locations.keys.each do |location|
      user = create(:user, location: location)
      expect(user.location_for(ShiftTime::RENTON_OPENING_DATE.prev_day)).to eq("Belltown")
    end
  end

  it "returns respective location after the change date" do
    ShiftTime::LOCATIONS_AFTER.each do |location|
      user = create(:user, location: location)
      expect(user.location_for(ShiftTime::RENTON_OPENING_DATE)).to eq(user.location)
    end
  end

  it "matches location for a request if the location on the date of the request is the same as the location of the request" do
    user = create(:user)
    request = create(:request, date: Faker::Date.unique(:in_the_next_year_post_location_change))
    expect(user.location_matches(request)).to eq(user.location == request.location)
  end

end
