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
    minimum_length = described_class.validators_on(:password).find {|v| v.kind == :length }.options[:minimum]
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

  it "logs in and out correctly"

end
