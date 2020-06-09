describe Request do
	# subject { Request.new(user_id: 104, shift: 3, date: Date.today) }

  before do
    r1 = create(:request)
    r1.save
    r2 = create(:request, user: create(:user, location: r1.user.location))
    @requests = [r1, r2]
    create(:availability, user: r2.user, date: r1.date, shift: r1.shift)
    @requests.each {|r| expect(r).to be_seeking_offers }
  end

  it "has a valid factory" do
    expect(create(:request)).to be_valid
  end

  it "allows creation even if conflicting availability is tied to sub/swap" do
    r = create(:request)
    subber = create(:user, location: r.location)
    r.fulfill_by_sub(subber)
    expect(create(:request, user: subber, date: r.date, shift: r.shift)).to be_valid
  end

  it "accepts a swap offer" do
    expect(@requests.first.send_swap_offer_to(@requests.second)).to be_truthy
    @requests.each do |r|
      expect(r).to_not be_changed # that is, saved
      r.reload
      expect(r).to_not be_seeking_offers
    end
    expect(@requests.first).to be_sent_offer
    expect(@requests.second).to be_received_offer
    (@requests + @requests.map(&:availability)).each {|x| expect(x).to_not be_active }
  end

  it "fails to offer swap if either request is not seeking offers" do
    types = [:request, :sent_offer_request, :received_offer_request, :fulfilled_request]
    requests = types.map {|t| create(t) }
    requests.product(requests).each do |sender, receiver|
      next if sender == receiver
      create(:availability, user: receiver.user, date: sender.date, shift: sender.shift)
      expect(sender.send_swap_offer_to(receiver)).to_not be_truthy
    end
  end

  def check_request_not_found(sender, receiver, destroyed_request: nil)
    expect(Request.destroy(destroyed_request.id)).to be_truthy
    expect(Request.exists?(destroyed_request.id)).to eq(false)
    expect { sender.send_swap_offer_to(receiver) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "fails to offer swap if the sending request is not found" do
    check_request_not_found(*@requests, destroyed_request: @requests.first)
  end

  it "fails to offer swap if the receiving request is not found" do
    check_request_not_found(*@requests, destroyed_request: @requests.second)
  end

  def users_in_different_locations
    user = create(:user)
    other_location = (ShiftTime::LOCATIONS_AFTER - [user.location]).sample
    [user, create(:user, location: other_location)]
  end

  it "fails to offer swap if locations don't match" do
    u1, u2 = users_in_different_locations

    date1 = Faker::Date.unique(:in_the_next_year_post_location_change)
    date2 = Faker::Date.unique(:in_the_next_year_post_location_change)

    sender = create(:request, user: u1, date: date1)
    receiver = create(:request, user: u2, date: date2)
    create(:availability, user: receiver.user, date: sender.date, shift: sender.shift)

    expect(sender.send_swap_offer_to(receiver)).to_not be_truthy
  end

  it "returns a match for offerable swaps" do
    location = ShiftTime::LOCATIONS_AFTER.sample
    senders_request, receivers_request = requests_in_locations(location, location)
    receivers_availability = receivers_request.user.availability_for(senders_request)
    receivers_availability.free = true
    receivers_availability.save!
    match_type = Request::MATCH_TYPE_MAP[:offerable_swaps]

    found_match = senders_request.match(receivers_request,
      senders_availability: match_type[:senders_availability],
      receivers_availability: match_type[:receivers_availability],
      preloaded_requests: Request.future.to_a,
      preloaded_availabilities: Availability.future.to_a)

    expect(found_match).to eq(true)
  end

  it "returns no match for offerable swaps at different locations" do
    requests = create(:belltown_request), create(:renton_request)
    senders_request, receivers_request = requests.shuffle
    receivers_availability = receivers_request.user.availability_for(senders_request)
    receivers_availability.free = true
    receivers_availability.save!
    match_type = Request::MATCH_TYPE_MAP[:offerable_swaps]

    found_match = senders_request.match(receivers_request,
      senders_availability: match_type[:senders_availability],
      receivers_availability: match_type[:receivers_availability],
      preloaded_requests: Request.future.to_a,
      preloaded_availabilities: Availability.future.to_a)

    expect(found_match).to eq(false)
  end

  context "when state is seeking_offers" do
    subject { FactoryBot.create(:request) }
    let(:subber) { create(:user, location: subject.location) }

    it "can fulfill_by_sub" do
      expect(subject.fulfill_by_sub(subber)).to eq(true)
      should be_fulfilled
      expect(subject).to be_fulfilled
      expect(subber.availabilities.find_by_shifttime(subject)).to_not be_free
    end

    it "fails fulfill_by_sub if request is not found" do
      expect(Request.destroy(subject.id)).to be_truthy
      expect(Request.exists?(subject.id)).to eq(false)
      expect { subject.fulfill_by_sub(subber) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "fails fulfill_by_sub if subber is not available" do
      create(:availability, user: subber, date: subject.date, shift: subject.shift, free: false)
      expect(subject.fulfill_by_sub(subber)).to be_falsey
    end

    it "fails fulfill_by_sub if subber has a conflicting request" do
      create(:request, user: subber, date: subject.date, shift: subject.shift)
      expect { subject.fulfill_by_sub(subber) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context "when state is received_offer" do
    subject { create(:received_offer_request) }

    it "can accept_pending_swap" do
      expect(subject.accept_pending_swap).to eq(true)
      [subject, subject.fulfilling_swap].each do |r|
        expect(r).to_not be_changed
        expect(r).to be_fulfilled
      end
    end

    it "can decline_pending_swap" do
      sender = subject.fulfilling_swap
      expect(subject.decline_pending_swap).to eq(true)
      sender.reload
      [subject, sender].each do |r|
        expect(r).to_not be_changed
        expect(r).to be_seeking_offers
        expect(r.fulfilling_swap).to be_nil
      end
    end
  end

  describe "#decline_pending_swap" do
    subject { FactoryBot.create(:received_offer_request) }
    before(:each) { expect(subject.decline_pending_swap).to eq(true) }
    it { should_not be_changed }
    it { should be_seeking_offers }
    it "has no fulfilling_swap" do
      expect(subject.fulfilling_swap).to be_nil
    end
    it "has no availability" do
      expect(subject.availability).to be_nil
    end
  end

  context "when state is not received_offer" do
    it "will fail to accept_pending_swap" do
      types = [:request, :sent_offer_request, :fulfilled_request]
      types.each do |t|
        r = create(t)
        expect(r.accept_pending_swap).to be_falsey
      end
    end
  end

  context "when not seeking_offers" do
    # Find a way to share among all non-seeking_offer states
    describe FactoryBot.create(:sent_offer_request) do
      it "can't be destroyed" do
        expect(subject.destroy).to eq(false)
      end
    end
  end
end
