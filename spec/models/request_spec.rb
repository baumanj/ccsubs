describe Request do
	# subject { Request.new(user_id: 104, shift: 3, date: Date.today) }

  before do
    r1 = create(:request)
    r2 = create(:request, date: r1.date + 1)
    create(:availability, user: r2.user, date: r1.date, shift: r1.shift)
    @requests = [r1, r2]
    @requests.each {|r| expect(r).to be_seeking_offers }


    a1 = create(:availability)
    begin
      a2 = create(:availability)
    while a1.start == a2.start
    @sent_offer_request = build(:request, user: a1.user, date: a2.date, shift: a2.shift, state: :sent_offer,
                                availability: a2, fulfilling_swap: @received_offer_request)
    @received_offer_request = create(:request, date, )

    @fulfilled_request =
  end

  it "has a valid factory" do
    expect(create(:request)).to be_valid
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
  end

  it "fails to offer swap if receiver is not seeking offers" do
    expect(@requests.first.send_swap_offer_to(@requests.second)).to be_truthy
    r = create(:request, date: @requests.first.date, shift: @requests.first.shift)
    expect(r.send_swap_offer_to(@requests.second)).to_not be_truthy
    expect(r).to be_changed
    r.reload
    expect(r).to be_seeking_offers
  end

  it "fails to offer swap if receiving request is not found" do
    expect(Request.destroy(@requests.second.id)).to be_truthy
    expect(Request.exists?(@requests.second.id)).to eq(false)
    expect(@requests.first.send_swap_offer_to(@requests.second)).to_not be_truthy
  end

  it "fails to offer swap if receiving request is not seeking offers" do

    expect(@requests.first.send_swap_offer_to(@requests.second)).to_not be_truthy
  end

  it "fails to offer swap if sending request is not found" do
  end

  it "fails to offer swap if sending request is not seeking offers" do
  end


  it 'is the fulfilling swap of its fulfilling swap' do
    r, r2, r3, r4 = create_list(:request, 4)

    r.fulfilling_swap = r2
    expect(r.fulfilling_swap.object_id).to eq(r2.object_id)
    expect(r2.fulfilling_swap.object_id).to eq(r.object_id)

    r2.fulfilling_swap = nil
    expect(r.fulfilling_swap).to be_nil
    expect(r2.fulfilling_swap).to be_nil

    r.fulfilling_swap = r2
    expect(r.fulfilling_swap.object_id).to eq(r2.object_id)
    expect(r2.fulfilling_swap.object_id).to eq(r.object_id)

    r.fulfilling_swap = r3
    expect(r.fulfilling_swap.object_id).to eq(r3.object_id)
    expect(r2.fulfilling_swap).to be_nil
    expect(r3.fulfilling_swap.object_id).to eq(r.object_id)

    r2.fulfilling_swap = r4
    expect(r.fulfilling_swap.object_id).to eq(r3.object_id)
    expect(r3.fulfilling_swap.object_id).to eq(r.object_id)
    expect(r2.fulfilling_swap.object_id).to eq(r4.object_id)
    expect(r4.fulfilling_swap.object_id).to eq(r2.object_id)

    r.fulfilling_swap = r2
    expect(r.fulfilling_swap.object_id).to eq(r2.object_id)
    expect(r2.fulfilling_swap.object_id).to eq(r.object_id)
    expect(r3.fulfilling_swap).to be_nil
    expect(r4.fulfilling_swap).to be_nil
	end
end
