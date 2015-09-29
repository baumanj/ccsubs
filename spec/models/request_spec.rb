describe Request do
	# subject { Request.new(user_id: 104, shift: 3, date: Date.today) }

  before do
    r1, r2 = @requests = create_list(:request, 2)
    create(:availability, user: r2.user, date: r1.date, shift: r1.shift)
    @requests.each {|r| expect(r).to be_seeking_offers }
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

  it "fails to offer swap if either request is not seeking offers" do
    types = [:request, :sent_offer_request, :received_offer_request, :received_offer_request]
    requests = types.map {|t| create(t) }
    requests.product(requests).each do |sender, receiver|
      next if sender == receiver
      create(:availability, user: receiver.user, date: sender.date, shift: sender.shift)
      puts "#{sender.inspect} sending offer to #{receiver.inspect}"
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
end
