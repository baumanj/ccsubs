describe Availability do # without any subject, just calls Availability.new ?
  subject { puts "subject block called"; create(:availability) }
  # puts subject.inspect # needs to be in an it block
  before { puts "Called outer before" }
  it { should_not be_nil }
  it { should be_free }

  # describe FactoryGirl.create(:availability) do
  #   before(:all) { puts "Called inner before" }
  #   it { should_not be_nil }
  #   it { should be_free }
  #   # its(:free) { should eq(true) }
  # end

  # it "prints the subject AGAIN" do
  #   puts subject.inspect
  #   it { should_not be_empty }
  # end

	#subject { [] }
	# it { is_true }

  it "notifies potential matches" do
    # Alice has a request A, Bob has a request B
    # When Bob saves a new availability for A, Alice should receive an email
    a, b = create_list(:seeking_offers_request, 2)
    bobs_availability = build(:availability, user: b.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(ActionMailer::Base.deliveries.last).to eq(UserMailer.notify_potential_matches(a, [b]))
  end
end
