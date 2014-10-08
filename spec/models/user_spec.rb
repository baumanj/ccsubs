require 'spec_helper'

describe User do
  before { @user = User.new(name: 'a b', email: 'a@b.com') }
  
  subject { @user }
  
  it { should respond_to(:name) }
  it { should respond_to(:email) }
  it { should respond_to(:password_digest) }
end
