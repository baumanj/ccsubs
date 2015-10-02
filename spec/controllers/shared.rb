shared_context "logged in" do
  before { subject.current_user = create(:user) }
end

shared_context "logged in and confirmed" do
  before { subject.current_user = create(:confirmed_user) }
end

# Expects the first example group under the "describe controller" group to be
# a string of the form "HTTP_METHOD 'controller_action'"
# e.g., "GET 'index'" or "PATCH 'offer_sub'"
redirect_shared_example = proc do |context: nil, expect_redirect_to: :url_for, expect_redirect_to_url_for: nil|
  proc do
    include_context context unless context.nil?
    controller, method, action = metadata[:full_description].scan(/\w+/)
    it "redirects to #{expect_redirect_to} #{Array(expect_redirect_to_url_for).join(', ')}" do
      resolved_expect_redirect_to_url_for = *Array(expect_redirect_to_url_for).map {|a| subject.send(a) }
      redirect_url = subject.send(expect_redirect_to, resolved_expect_redirect_to_url_for)
      send(method.downcase, action)
      expect(response).to redirect_to(redirect_url)
    end
  end
end

shared_examples("an action needing login",
  &redirect_shared_example.call(expect_redirect_to: :signin_url))

shared_examples("an action needing user confirmation",
  &redirect_shared_example.call(context: "logged in", expect_redirect_to_url_for: :current_user))

shared_examples("an action needing admin",
  &redirect_shared_example.call(context: "logged in", expect_redirect_to: :root_url))
