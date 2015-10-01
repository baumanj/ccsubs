shared_context "logged in" do
  before { subject.current_user = create(:user) }
end

shared_examples "an action needing login" do
  method, action = metadata[:parent_example_group][:description].scan(/\w+/)
  it "redirects to signin" do
    send(method.downcase, action)
    expect(response).to redirect_to(signin_url)
  end
end

shared_examples "an action needing admin" do
  method, action = metadata[:parent_example_group][:description].scan(/\w+/)
  it "redirects to signin" do
    send(method.downcase, action)
    expect(response).to redirect_to(root_url)
  end
end
