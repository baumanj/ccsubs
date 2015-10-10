# Expects the first example group under the "describe controller" group to be
# a string of the form "HTTP_METHOD 'controller_action'"
# e.g., "GET 'index'" or "PATCH 'offer_sub'"
# Is there a way to just share this context in the top level controller describe?
shared_context "do request in before", autorequest: true do
  controller, method, action = metadata[:full_description].scan(/\w+/)

  let(:params) { {} }
  let(:evaluate_before_http_request) { }
  let(:rendered_template) { action }

  before do
    evaluate_before_http_request
    subject.current_user = user
    send(method.downcase, action, params)
    expect(response).to render_template(rendered_template) unless response.redirect?
  end
end

shared_context "not logged in" do
  let(:user) { nil }
end

shared_context "logged in" do
  let(:user) { create(:user) }
end

shared_context "logged in and confirmed" do
  let(:user) { create(:confirmed_user) }
end

shared_context "logged in as an admin", login: :admin do
  let(:user) { create(:admin) }
end

shared_context "must be logged in", requires: :login do
  it_behaves_like "an action needing login"
  include_context "logged in"
end

shared_context "current user must be confirmed", requires: :confirmed_current_user do
  it_behaves_like "an action needing user confirmation"
  include_context "logged in and confirmed"
end

shared_context "current user must be an admin", requires: :admin do
  it_behaves_like "an action needing an admin"
  include_context "logged in as an admin"
end

example_proc = proc do |context: nil, expect_redirect_to: nil|
  proc do
    include_context context
    it "redirects to #{expect_redirect_to}" do
      expect(response).to redirect_to(subject.send(expect_redirect_to))
    end
  end
end

shared_examples("an action needing login",
  &example_proc.call(context: "not logged in", expect_redirect_to: :signin_url))

shared_examples("an action needing user confirmation",
  &example_proc.call(context: "logged in", expect_redirect_to: :current_user))

shared_examples("an action needing an admin",
  &example_proc.call(context: "logged in and confirmed", expect_redirect_to: :root_url))
