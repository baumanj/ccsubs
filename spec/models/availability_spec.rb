# A second may elapse between the generation of the mail and the
# expected mail object, so ignore the date altogether
RSpec::Matchers.define :eq_mailers do |*expected|
  match do |actual|
    actual = [*actual]
    (expected + actual).each {|m| m.date = nil }
    expected.sort == actual.sort
  end
end

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

  it "notifies potential matches about updated availability" do
    # Alice has a request A, Bob has a request B
    # When Bob saves a new availability for A, Alice should receive an email
    a, b = create_list(:seeking_offers_request, 2)
    bobs_availability = build(:availability, user: b.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(ActionMailer::Base.deliveries.last).to eq_mailers(UserMailer.notify_potential_matches(a, [b]))
  end

  it "notifies full matches about updated availability" do
    # Alice has a request A, Bob has a request B and Alice is available for B
    # When Bob saves a new availability for A, Alice should receive an email
    a = create(:seeking_offers_request)
    alices_availability = create(:availability, user: a.user)
    b = create(:seeking_offers_request, date: alices_availability.date, shift: alices_availability.shift)
    bobs_availability = build(:availability, user: b.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(ActionMailer::Base.deliveries.last).to eq_mailers(UserMailer.notify_full_matches(a, [b]))
  end

  it "notifies multiple users about updated availability" do
    # Alice has a request A, Bob has a request B and Clarice has request C at the same time as A
    # When Bob saves a new availability for A/C, Alice and Clarice should receive an email
    a, b = create_list(:seeking_offers_request, 2)
    c = create(:seeking_offers_request, date: a.date, shift: a.shift)
    bobs_availability = build(:availability, user: b.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(2)
    mail_to_alice = UserMailer.notify_potential_matches(a, [b])
    mail_to_clarice = UserMailer.notify_potential_matches(c, [b])
    expect(ActionMailer::Base.deliveries.last(2)).to eq_mailers(mail_to_alice, mail_to_clarice)
  end

  it "notifies full matches over potential matches" do
    # Alice has a request A, Bob has a requests B1 and B2 and Alice is available for B1
    # When Bob saves a new availability for A, Alice should receive an email about the full match
    a = create(:seeking_offers_request)
    alices_availability = create(:availability, user: a.user)
    b1 = create(:seeking_offers_request, date: alices_availability.date, shift: alices_availability.shift)
    b2 = create(:seeking_offers_request, user: b1.user)
    expect(b1.user).to eq(b2.user)
    bobs_availability = build(:availability, user: b1.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(ActionMailer::Base.deliveries.last).to eq_mailers(UserMailer.notify_full_matches(a, [b1]))
  end

  it "can't be deleted when tied to a future request" do
    a = create(:fulfilled_request).availability
    a.destroy
    expect(a.destroyed?).to be(false)

    allow(Time).to receive(:current).and_return(a.end)
    a.destroy
    expect(a.destroyed?).to be(true)
  end

end
