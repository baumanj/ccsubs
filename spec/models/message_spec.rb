require 'rails_helper'

RSpec.describe Message, type: :model do

  it "has a valid factory" do
    expect(create(:message)).to be_valid
  end

  it 'accepts a shift that has started' do
    todays_shift_ranges = ShiftTime::time_to_shift_time_ranges
    todays_shift_ranges.each do |shift_range|
      current_time = shift_range.end - 30.minutes
      expect(shift_range).to cover(current_time)
      allow(Time).to receive(:current).and_return(current_time)
      expect(create(:message, date: Date.today, shift: ShiftTime::time_to_shift)).to be_valid
    end
  end

  it 'rejects a shift that has ended' do
    todays_shift_ranges = ShiftTime::time_to_shift_time_ranges
    todays_shift_ranges.each_with_index do |shift_range, shift|
      current_time = shift_range.end + 30.minutes
      expect(shift_range).to_not cover(current_time)
      allow(Time).to receive(:current).and_return(current_time)
      expect { create(:message, date: Date.today, shift: shift) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
