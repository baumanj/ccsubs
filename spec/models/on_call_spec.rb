require 'rails_helper'

RSpec.describe OnCall, type: :model do

  it "rejects a shift before the first valid date" do
    expect { create(:on_call, date: OnCall::FIRST_VALID_DATE.prev_day) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "rejects a sign-up for a shift that started in the past" do
    date, shift = ShiftTime.last_started_date_and_shift
    expect { create(:on_call, date: date, shift: shift) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "accepts a signup for the next shift to start" do
    date, shift = ShiftTime.next_date_and_shift
    expect(create(:on_call, date: date, shift: shift)).to be_valid
  end

  it "rejects a shift more than a year from now" do
    date = [OnCall::FIRST_VALID_DATE, Date.today].max.next_day
    expect { create(:on_call, date: date + 1.year) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "rejects a second sign-up for the same shift" do
    first = create(:on_call)
    expect { create(:on_call, date: first.date, shift: first.shift) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "rejects a second sign-up for the same user in a month" do
    dates = Date.today.next_month.all_month.to_a.sample(2)
    first = create(:on_call, date: dates.first)
    expect { create(:on_call, date: dates.second, user: first.user) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "makes the user unavabliable for swaps at that time" do
    oc = create(:on_call)
    expect(oc.user.availability_for(oc)).to_not be_free
  end

  it "makes the user available again if deleted" do
    oc = create(:on_call)
    expect(oc.prior_availability).to be_nil
    oc.destroy!
    expect(oc.user.availability_for(oc).free).to be_nil
  end

  it "restores existing availability status if deleted" do
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

  context "for a given date range" do
    let(:date_range) { d = Faker::Date::in_the_next_year; (d)...(d.next_day) }

    context "when you're a recurring shift volunteer" do
      let!(:you) { create(:recurring_shift_volunteer) }

      it "nags if haven't signed up for a shift in the date range" do
        create(:on_call, user: you, date: date_range.last.next_day)
        expect(OnCall.users_to_nag(date_range)).to include(you)
      end

      it "doesn't nag if you have signed up for a shift in the date range" do
        create(:on_call, user: you, date: date_range.to_a.sample)
        expect(OnCall.users_to_nag(date_range)).to_not include(you)
      end

      it "doesn't nag if all the slots are full" do
        date_range.each do |date|
          OnCall.shifts.each_value {|s| create(:on_call, date: date, shift: s) }
        end
        expect(OnCall.users_to_nag(date_range)).to_not include(you)
      end
    end

    context "when you're a disabled user" do
      let!(:you) { create(:recurring_shift_volunteer, disabled: true) }

      it "doen't nag if haven't signed up for a shift in the date range" do
        expect(OnCall.users_to_nag(date_range)).to_not include(you)
      end
    end

    context "when you're not a recurring shift volunteer" do
      let!(:you) { create(:non_recurring_shift_volunteer) }

      it "doen't nag if haven't signed up for a shift in the date range" do
        expect(OnCall.users_to_nag(date_range)).to_not include(you)
      end
    end
  end

end
