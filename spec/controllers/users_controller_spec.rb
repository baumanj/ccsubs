require 'controllers/shared'

class StringFileUpload < StringIO
  # Otherwise ActionController::TestCase::Behavior#paramify_values
  # will convert this into a String
  def to_param
    self
  end
end

# Just like contain_exactly, except we assume the array elements are
# users and compare them considering only attributes that are
# present in the CSV headers
RSpec::Matchers.define :contain_exactly_the_users do |expected, headers|
  match do |actual|
    expected_set, actual_set = [expected, actual].map do |user_array|
      user_array.map {|u| u.attributes.fetch_values(*headers) }.to_set
    end
    expected_set == actual_set
  end
end

describe UsersController do

  describe "POST 'upload_csv'", autorequest: true, requires: :admin do
    context 'when admin' do
      let(:evaluate_before_http_request) do
        @users_before = User.all.to_a
      end

      shared_examples "an invalid upload" do
        let(:expect_flash_error_to) { be_nonempty }
        let(:expected_assigns) { { users_to_disable: be_any } }

        it "doesn't change the users" do
          expect(User.all.to_a.inspect).to eq(@users_before.inspect)
        end
      end

      context "when error occurs" do
        let(:rendered_template) { "users/new_list" }
        context 'when no file is uploaded' do
          it_behaves_like 'an invalid upload'
        end

        context 'when passed an empty file' do
          let(:params) { { csv: StringFileUpload.new } }
          it_behaves_like 'an invalid upload'
        end

        context 'when passed too few CSV headers' do
          let(:params) do
            headers_less_one = UsersController::EXPECTED_CSV_HEADERS[0...-1]
            { csv: StringFileUpload.new(headers_less_one.to_csv) }
          end
          it_behaves_like 'an invalid upload'
        end

        context 'when passed too many CSV headers' do
          let(:params) do
            headers_plus_one = UsersController::EXPECTED_CSV_HEADERS + ['foo']
            { csv: StringFileUpload.new(headers_plus_one.to_csv) }
          end
          it_behaves_like 'an invalid upload'
        end

        context 'when new user has invalid user type' do
          let(:params) do
            invalid_user_type = UsersController::EXPECTED_CSV_HEADERS.to_csv + "bob,warm line,,,,\n"
            { csv: StringFileUpload.new(invalid_user_type) }
          end
          it_behaves_like 'an invalid upload'
        end

        context 'when an existing user has invalid user type' do # XXX
          let(:params) do
            invalid_user = @users_before.sample
            csv_string = CSV.generate do |csv|
              csv << UsersController::EXPECTED_CSV_HEADERS
              csv << UsersController::EXPECTED_CSV_HEADERS.map do |h|
                if h == "volunteer_type"
                  "some bogus type"
                else
                  invalid_user.send(h)
                end
              end
            end
            { csv: StringFileUpload.new(csv_string) }
          end
          it_behaves_like 'an invalid upload'
        end

      end

      context "when CSV is valid" do
        let(:params) do
          csv_string = CSV.generate do |csv|
            csv << UsersController::EXPECTED_CSV_HEADERS
            csv_users.each do |new_user|
              csv << UsersController::EXPECTED_CSV_HEADERS.map {|h| new_user.send(h) }
            end
          end
          { csv: StringFileUpload.new(csv_string) }
        end

        context 'when adding new users', expect_redirect_to: :users_path do
          let(:csv_users) { build_list(:user, 10) + @users_before }

          it "adds the new users" do
            expect(User.all.to_a).to_not eq(@users_before)
            expect(User.all.to_a).to contain_exactly_the_users(csv_users, UsersController::EXPECTED_CSV_HEADERS)
          end

          it "doesn't remove the existing users" do
            expect(@users_before - User.all).to be_none
          end
        end

        context 'when adding a user with the same name but different vic', expect_redirect_to: :users_path do
          let(:csv_users) { @users_before + [create(:user, name: @users_before.sample.name)] }

          it "adds the new users" do
            expect(User.all.to_a).to_not eq(@users_before)
            expect(User.all.to_a).to contain_exactly_the_users(csv_users, UsersController::EXPECTED_CSV_HEADERS)
          end

          it "doesn't remove the existing users" do
            expect(@users_before - User.all).to be_none
          end
        end

        context "when existing users aren't present in CSV", expect_redirect_to: :users_path do
          let(:evaluate_before_http_request) do
            @existing_users = create_list(:user, 30)
            create_list(:user, 2).each {|u| u.update_attribute(:vic, nil) } # Skips validation
          end
          let(:csv_users) { @existing_users.sample(28) }
          let(:evaluate_after_http_request) do
            @existing_users.each(&:reload)
            @existing_users_with_vic, @existing_users_without_vic = @existing_users.partition(&:vic)
          end

          it "disables them (unless they have a nil VIC, which implies a special account)" do
            expect(@existing_users_with_vic - csv_users).to all(be_disabled)
            expect(@existing_users_without_vic).to_not include(be_disabled)
          end
        end

        context "when existing users have attributes different from CSV (save location)" do
          let(:evaluate_before_http_request) { @existing_users = create_list(:user, 10) }
          let(:csv_users) { @existing_users.map {|u| build(:user, vic: u.vic, location: u.location) } }
          let(:evaluate_after_http_request) do
            @reloaded_existing_users = User.where(id: @existing_users.map(&:id))
          end

          it "updates them" do
            headers_except_email = UsersController::EXPECTED_CSV_HEADERS - ['email']
            expect(@reloaded_existing_users).to contain_exactly_the_users(csv_users, headers_except_email)
            expect(@reloaded_existing_users.map(&:updated_at)).to all(be > @time_before_http_request)
          end

          it "doesn't update email, since that is user for login" do
            expect(@reloaded_existing_users).to contain_exactly_the_users(@existing_users, ['email'])
          end
        end

        context "when disabled users are present in CSV" do
          let(:evaluate_before_http_request) do
            @endabled_users = create_list(:user, 10)
            @disabled_users = create_list(:user, 10, disabled: true)
          end
          let(:csv_users) { @endabled_users + @disabled_users }
          let(:evaluate_after_http_request) { @disabled_users.each(&:reload) }

          it "reenables them" do
            expect(@disabled_users).to_not include(be_disabled)
          end
        end

        context "when a user changes locations" do
          let(:evaluate_before_http_request) do
            @users_before = User.all.to_a
          end
          let(:csv_users) {
            @users_before.map do |u|
              User.new(u.attributes.merge(location: u.location == "Belltown" ? "Renton" : "Belltown"))
            end
          }

          let(:rendered_template) { "users/new_list" }
          let(:expect_flash_error_to) { be_nonempty }

          it "doesn't change the users" do
            expect(User.all.to_a.inspect).to eq(@users_before.inspect)
          end
        end

        context "when only new users are specified in CSV (check against disabling > 10%)" do
          let(:evaluate_before_http_request) do
            create_list(:user, 4)
            @users_before = User.all.to_a
          end
          let(:expected_assigns) { { users_to_disable: contain_exactly(*@users_before) } }
          let(:csv_users) { build_list(:user, 2) }

          let(:rendered_template) { "users/new_list" }
          let(:expect_flash_error_to) { be_nonempty }

          it "doesn't change the users" do
            expect(User.all.to_a.inspect).to eq(@users_before.inspect)
          end
        end

        context 'when confirming an update that will disable > 10%', expect_redirect_to: :users_path do
          let(:evaluate_before_http_request) do
            create_list(:user, 4)
            @users_before = User.all.to_a
          end
          let(:params) { super().merge(users_to_disable_confirmation: @users_before.size) }
          let(:csv_users) { build_list(:user, 2) }
          let(:users_to_disable_confirmation) { @users_before.size }

          it "adds the new users" do
            expect(User.all.to_a).to_not eq(@users_before)
            expect(User.active.to_a).to contain_exactly_the_users(csv_users, UsersController::EXPECTED_CSV_HEADERS)
          end
        end

      end

    end
  end

end
