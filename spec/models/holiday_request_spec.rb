require 'rails_helper'

RSpec.describe HolidayRequest, type: :model do

  it "has a valid factory" do
    expect(create(:holiday_request)).to be_valid
  end

  it "has no user" do
    expect(create(:holiday_request).user).to be_nil
  end

  it "rejects a swap offer" do
    hr = create(:holiday_request)
    non_hr = create(:request)
    expect { hr.send_swap_offer_to(non_hr) }.to raise_error(TypeError)
    expect { non_hr.send_swap_offer_to(hr) }.to raise_error(TypeError)
  end

  context "when state is seeking_offers" do
    subject { FactoryGirl.create(:holiday_request) }
    let(:subber) { create(:user) }

    it "can fulfill_by_sub" do
      expect(subject.fulfill_by_sub(subber)).to eq(true)
      should be_fulfilled
      expect(subber.availabilities.find_by_shifttime(subject)).to_not be_free
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

  it "Only creates Xmas eve requests for the last two shifts" do
    HolidayRequest.create_any_not_present
    xmas_eve_reqs = HolidayRequest.where(date: Holiday.next_date(Holiday::CHRISTMAS_EVE))
    expect([xmas_eve_reqs.map(&:shift).uniq]).to contain_exactly(HolidayRequest.shifts.keys.last 2)
  end

  it "Correctly creates new holiday requests" do
    allow(Time).to receive(:current).and_return(Time.new(2018, 1, 16))
    HolidayRequest.create_any_not_present
    puts HolidayRequest.find_by(date: Holiday.next_date(Holiday::MARTIN_LUTHER_KING_JR_DAY))
  end
end
