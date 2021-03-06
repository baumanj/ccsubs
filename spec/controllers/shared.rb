RSpec::Matchers.define_negated_matcher :be_nonempty, :be_empty

# Expects the first example group under the "describe controller" group to be
# a string of the form "HTTP_METHOD 'controller_action'"
# e.g., "GET 'index'" or "PATCH 'offer_sub'"
# Is there a way to just share this context in the top level controller describe?
shared_context "do request in before", autorequest: true do
  controller, method, action = metadata[:full_description].scan(/\w+/)

  let(:params) { {} }
  let(:evaluate_before_http_request) { }
  let(:evaluate_after_http_request) { }
  let(:rendered_template) { }
  let(:rendered_templates) { [rendered_template] if rendered_template }
  let(:expected_assigns) { {} }
  let(:expect_flash_error_to) { be_nil }

  before do
    subject.current_user = current_user
    request.env["HTTP_REFERER"] = root_url
    evaluate_before_http_request
    @time_before_http_request = Time.current
    send(method.downcase, action, params)
    evaluate_after_http_request

    if response.redirect?
      defaut_template = nil
    else
      defaut_template = action
      expect(response).to be_success
    end

    (rendered_templates || [defaut_template]).each do |t|
      expect(response).to render_template(t)
    end

    expect(flash[:error]).to expect_flash_error_to

    expected_assigns.merge!(
      current_user: eq(subject.current_user),
      marked_for_same_origin_verification: eq(true).or(eq(false))
    )
    assigns.each do |var_name, value|
      expect(expected_assigns).to include(var_name.to_sym)
      if !expected_assigns[var_name.to_sym].matches?(value)
        puts "#{var_name} did not match"
      end
      expect(value).to expected_assigns[var_name.to_sym]
    end
  end
end

shared_context "expect flash error to be set", expect: :flash_error do
  let(:expect_flash_error_to) { be_nonempty }
end

shared_context "no template rendered", rendered: nil do
  let(:rendered_template) { nil }
end

shared_context "not logged in" do
  let(:current_user) { nil }
end

shared_context "logged in" do
  let(:current_user) { create(:user) }
end

shared_context "logged in and confirmed" do
  let(:current_user) { create(:confirmed_user) }
end

shared_context "logged in as an admin", login: :admin do
  let(:current_user) { create(:admin) }
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
    [*context].each {|c| include_context c }
    # include_context context
    it "redirects to #{expect_redirect_to}" do
      expect(response).to redirect_to(subject.send(expect_redirect_to))
    end
  end
end

shared_examples("an action needing login",
  &example_proc.call(context: "not logged in", expect_redirect_to: :signin_url))

shared_examples("an action needing user confirmation",
  &example_proc.call(context: ["logged in", "no template rendered"], expect_redirect_to: :current_user))

shared_examples("an action needing an admin",
  &example_proc.call(context: "logged in and confirmed", expect_redirect_to: :root_url))
