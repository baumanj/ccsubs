describe Availability do # without any subject, just calls Availability.new ?
  subject { puts "subject block called"; create(:availability) }
  # puts subject.inspect # needs to be in an it block
  before { puts "Called outer before" }
  it { should_not be_nil }
  it { should be_free }

  describe FactoryGirl.create(:availability) do
    before(:all) { puts "Called inner before" }
    it { should_not be_nil }
    it { should be_free }
    # its(:free) { should eq(true) }
  end

  # it "prints the subject AGAIN" do
  #   puts subject.inspect
  #   it { should_not be_empty }
  # end

	#subject { [] }
	# it { is_true }
end
