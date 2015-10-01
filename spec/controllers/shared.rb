shared_context "logged in" do
  before { subject.current_user = create(:user) }
end

shared_context "logged in and confirmed" do
  before { subject.current_user = create(:confirmed_user) }
end

# Expects the first example group under the "describe controller" group to be
# a string of the form "HTTP_METHOD 'controller_action'"
# e.g., "GET 'index'" or "PATCH 'offer_sub'"
redirect_shared_example = proc do |redirect_url_method, redirect_url_args|
  proc do
    controller, method, action = metadata[:full_description].scan(/\w+/)
    it "redirects to #{redirect_url_method} #{Array(redirect_url_args).join(', ')}" do
      resolved_redirect_url_args = *Array(redirect_url_args).map {|a| subject.send(a) }
      redirect_url = subject.send(redirect_url_method, resolved_redirect_url_args)
      send(method.downcase, action)
      expect(response).to redirect_to(redirect_url)
    end
  end
end

shared_examples "an action needing login", &redirect_shared_example.call(:signin_url)
shared_examples "an action needing user confirmation", &redirect_shared_example.call(:url_for, :current_user)
shared_examples "an action needing admin", &redirect_shared_example.call(:root_url)
