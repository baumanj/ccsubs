require 'rails_helper'

RSpec.describe Message, type: :model do

  before do
    create_list(:user, 10)
  end

  it "has a valid factory" do
    expect(create(:message)).to be_valid
  end

  it 'accepts a shift that has started' do
    todays_shift_ranges = ShiftTime::shift_ranges
    todays_shift_ranges.each do |shift_range|
      current_time = shift_range.end - 30.minutes
      expect(shift_range).to cover(current_time)
      allow(Time).to receive(:current).and_return(current_time)
      expect(create(:message, date: Date.today, shift: ShiftTime::time_to_shift)).to be_valid
    end
  end

  it 'rejects a shift that has ended' do
    todays_shift_ranges = ShiftTime::shift_ranges
    todays_shift_ranges.each_with_index do |shift_range, shift|
      current_time = shift_range.end + 30.minutes
      expect(shift_range).to_not cover(current_time)
      allow(Time).to receive(:current).and_return(current_time)
      expect { create(:message, date: shift_range.begin.to_date, shift: shift) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  let(:message) { create(:message) }

  it "excludes users who are unavailable" do
    unavailable_users = create_list(:user, 2)
    unavailable_users.each {|u| u.availability_for(message).update(free: false) }
    expect(message.recipients).to_not include(*unavailable_users)
  end

  context "when users are generally unavailable for that day/shift" do
    let!(:typically_unavailable_users) do
      create_list(:user, 2).each do |u|
        u.default_availability_for(message).update(free:false)
      end
    end

    it "excludes them if they aren't explicitly free for that instance" do
      typically_unavailable_users.first.availability_for(message).update(free: false)
      typically_unavailable_users.second.availability_for(message).update(free: nil)
      expect(message.recipients).to_not include(*typically_unavailable_users)
    end

    it "includes them if they are free for that instance" do
      typically_unavailable_users.each {|u| u.availability_for(message).update(free: true) }
      expect(message.recipients).to include(*typically_unavailable_users)
    end
  end

  shared_examples "there are requests for that shift" do
    let(:request_owners) { requests.map(&:user) }

    it "excludes the requests' owners" do
      expect(message.recipients).to_not include(*request_owners)
    end
  end

  context "when there are requests for that shift seeking offers" do
    let!(:requests) { create_list(:seeking_offers_request, 2, message.shifttime_attrs) }

    it_behaves_like "there are requests for that shift"
  end

  context "when there are requests for that shift with a pending or fulfilled offer" do
    let!(:requests) do
      [:sent_offer_request, :received_offer_request, :fulfilled_request].map do |t|
        create(t, message.shifttime_attrs)
      end
    end

    it_behaves_like "there are requests for that shift"
    it "excludes the users fulfilling the requests" do
      fulfilling_users = requests.map(&:fulfilling_user)
      expect(message.recipients).to_not include(*fulfilling_users)
    end
  end

  it "excludes users who typically work this shift"

end
