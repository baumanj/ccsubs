shared_context "logged in" do
  before { current_user = create(:user) }
end
