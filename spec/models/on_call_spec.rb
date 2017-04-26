require 'rails_helper'

RSpec.describe OnCall, type: :model do

  it 'rejects a shift before the first valid date' do
    expect { create(:on_call, date: OnCall::FIRST_VALID_DATE.prev_day) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'accepts a shift on the first valid date' do
    expect(create(:on_call, date: OnCall::FIRST_VALID_DATE)).to be_valid
  end

  it 'rejects a shift more than a year from now' do
    date = [OnCall::FIRST_VALID_DATE, Date.today].max.next_day
    expect { create(:on_call, date: date + 1.year) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'rejects a second sign-up for the same shift' do
    first = create(:on_call)
    expect { create(:on_call, date: first.date, shift: first.shift) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'rejects a second sign-up for the same user in a month' do
    dates = [OnCall::FIRST_VALID_DATE, Date.today].max.all_month.to_a.sample(2)
    first = create(:on_call, date: dates.first)
    expect { create(:on_call, date: dates.second, user: first.user) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'makes the user unavabliable for swaps at that time' do
    oc = create(:on_call)
    expect(oc.user.availability_for(oc)).to_not be_free
  end

  it 'makes the user available again if deleted' do
    oc = create(:on_call)
    expect(oc.prior_availability).to be_nil
    oc.destroy!
    expect(oc.user.availability_for(oc).free).to be_nil
  end

  it 'restores existing availability status if deleted' do
    [true, false].each do |free|
      oc = build(:on_call)
      a = oc.user.availability_for(oc)
      a.free = free
      a.save!
      oc.save!
      expect(oc.prior_availability).to eq(free)
      oc.destroy!
      expect(oc.user.availability_for(oc).free).to eq(free)
    end
  end

end
