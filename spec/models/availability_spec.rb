# A second may elapse between the generation of the mail and the
# expected mail object, so ignore the date altogether and only
# concern ourselves with the equality of the body and recipient
RSpec::Matchers.define :eq_mailers do |*expected|
  match do |actual|
    actual = [*actual]
    expected.sort_by(&:to).zip(actual.sort_by(&:to)).all? do |e, a|
      e.body.to_s == a.body.to_s && e.to == a.to
    end
  end
end

describe Availability do # without any subject, just calls Availability.new ?
  subject { puts "subject block called"; create(:availability) }
  # puts subject.inspect # needs to be in an it block
  before { puts "Called outer before" }
  it { should_not be_nil }
  it { should be_free }

  # describe FactoryBot.create(:availability) do
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

  it "notifies potential matches in the same location about updated availability" do
    # Alice has a request A, Bob has a request B
    # When Bob saves a new availability for A, Alice should receive an email
    location = ShiftTime::LOCATIONS_AFTER.sample
    a, b = requests_in_locations(location, location)
    bobs_availability = build(:availability, user: b.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(ActionMailer::Base.deliveries.last).to eq_mailers(UserMailer.notify_potential_matches(a, [b]))
  end

  it "does not notify potential matches in different locations about updated availability" do
    # Alice has a request A in location1, Bob has a request B in location2
    # When Bob saves a new availability for A, Alice should not receive an email
    location1, location2 = ShiftTime::LOCATIONS_AFTER.sample(2)
    alice = create(:user, location: location1)
    bob = create(:user, location: location2)
    a = create(:request, user: alice, date: Faker::Date.unique(:in_the_next_year_for_renton))
    b = create(:request, user: bob, date: Faker::Date.unique(:in_the_next_year_for_renton))
    expect { bob.availability_for(a).update!(free: true) }.to change { ActionMailer::Base.deliveries.count }.by(0)
  end

  it "notifies full matches in the same location about updated availability" do
    # Alice has a request A, Bob has a request B and Alice is available for B
    # When Bob saves a new availability for A, Alice should receive an email
    a = create(:seeking_offers_request)
    alices_availability = create(:availability, user: a.user)
    bob = create(:user, location: a.user.location)
    b = create(:seeking_offers_request, user: bob, date: alices_availability.date, shift: alices_availability.shift)
    bobs_availability = build(:availability, user: b.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(1)
    expect(ActionMailer::Base.deliveries.last).to eq_mailers(UserMailer.notify_full_matches(a, [b]))
  end

  it "does not notifiy full matches in different locations about updated availability" do
    # Alice has a request A in location 1, Bob has a request B in location 2 and Alice is available for B
    # When Bob saves a new availability for A, Alice should not receive an email
    a = create(:belltown_request)
    b = create(:renton_request)
    expect(a.location).to_not eq(b.location)
    a.user.availability_for(b).update!(free: true)
    bobs_availability = b.user.availability_for(a)
    expect { bobs_availability.update!(free: true) }.to change { ActionMailer::Base.deliveries.count }.by(0)
  end

  it "notifies multiple users in the same location about updated availability" do
    # Alice has a request A, Bob has a request B and Clarice has request C at the same time as A
    # When Bob saves a new availability for A/C, Alice and Clarice should receive an email
    location = ShiftTime::LOCATIONS_AFTER.sample
    alice, bob, clarice = create_list(:user, 3, location: location)
    a = create(:seeking_offers_request, user: alice)
    b = create(:seeking_offers_request, user: bob)
    c = create(:seeking_offers_request, user: clarice, date: a.date, shift: a.shift)
    bobs_availability = build(:availability, user: b.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(2)
    mail_to_alice = UserMailer.notify_potential_matches(a, [b])
    mail_to_clarice = UserMailer.notify_potential_matches(c, [b])
    expect(ActionMailer::Base.deliveries.last(2)).to eq_mailers(mail_to_alice, mail_to_clarice)
  end

  it "only notifies users  in the same location about updated availability" do
    # Alice has a request A in location 1, Bob has a request B in location 1, Clarice has request C
    # at the same time as A in location 1 and David has a request D in location 2 at the same time as A.
    # When Bob saves a new availability for A/C/D, Alice and Clarice should receive an email, but David
    # should not.
    location1, location2 = ShiftTime::LOCATIONS_AFTER.sample(2)
    alice, bob, clarice = create_list(:user, 3, location: location1)
    david = create(:user, location: location2)
    a = create(:seeking_offers_request, user: alice, date: Faker::Date.unique(:in_the_next_year_for_renton))
    b = create(:seeking_offers_request, user: bob, date: Faker::Date.unique(:in_the_next_year_for_renton))
    c = create(:seeking_offers_request, user: clarice, date: a.date, shift: a.shift)
    d = create(:seeking_offers_request, user: david,   date: a.date, shift: a.shift)
    bobs_availability = build(:availability, user: b.user, date: a.date, shift: a.shift)
    expect { bobs_availability.save }.to change { ActionMailer::Base.deliveries.count }.by(2)
    mail_to_alice = UserMailer.notify_potential_matches(a, [b])
    mail_to_clarice = UserMailer.notify_potential_matches(c, [b])
    expect(ActionMailer::Base.deliveries.last(2)).to eq_mailers(mail_to_alice, mail_to_clarice)
  end

  it "notifies full matches in the same location over potential matches" do
    # Alice has a request A, Bob has requests B1 and B2 and Alice is available for B1
    # When Bob saves a new availability for A, Alice should receive an email about the full match
    a = create(:seeking_offers_request)
    alices_availability = create(:availability, user: a.user)
    bob = create(:user, location: a.user.location)
    b1 = create(:seeking_offers_request, user: bob, date: alices_availability.date, shift: alices_availability.shift)
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
