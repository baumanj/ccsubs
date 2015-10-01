shared_context "logged in" do
  before { subject.current_user = create(:user) }
end

redirect_shared_example = proc do |redirect_url|
  proc do
    method, action = metadata[:parent_example_group][:description].scan(/\w+/)
    it "redirects to #{redirect_url}" do
      send(method.downcase, action)
      expect(response).to redirect_to(send(redirect_url))
    end
  end
end

shared_examples "an action needing login", &redirect_shared_example.call(:signin_url)
shared_examples "an action needing admin", &redirect_shared_example.call(:root_url)
