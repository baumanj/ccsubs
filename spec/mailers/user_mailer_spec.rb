require "spec_helper"

describe UserMailer, :type => :mailer do

  before do
    UserMailer.active_user = create(:user)
  end

  describe "confirm_email"
  #   let(:mail) { UserMailer.confirm_email }

  #   it "renders the headers" do
  #     mail.subject.should eq("Confirm email")
  #     mail.to.should eq(["to@example.org"])
  #     mail.from.should eq(["from@example.com"])
  #   end

  #   it "renders the body" do
  #     mail.body.encoded.should match("Hi")
  #   end
  # end

  # describe "reset_password" do
  #   let(:mail) { UserMailer.reset_password }

  #   it "renders the headers" do
  #     mail.subject.should eq("Reset password")
  #     mail.to.should eq(["to@example.org"])
  #     mail.from.should eq(["from@example.com"])
  #   end

  #   it "renders the body" do
  #     mail.body.encoded.should match("Hi")
  #   end
  # end

  # describe "all_hands_email"
  #   let(:mail) { UserMailer.all_hands_email(['jon@shumi.org'], "test sub", "test bod") }

  #   it "does soemthing" do
  #     puts mail.subject
  #     puts mail.body
  #   end
end
