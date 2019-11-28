require 'rails_helper'

RSpec.describe Holiday, type: :helper do

  describe "name" do
    it "returns the right name when the current day is a holiday" do
      xmas_2018 = Date.new(2018, 12, 25)
      allow(Date).to receive(:current).and_return(xmas_2018)
      expect(Date.current).to eq(xmas_2018)
      expect(Holiday.name(xmas_2018)).to be(Holiday::CHRISTMAS_DAY)
    end

    it "returns the right name for a holiday in the past" do
      xmas_2018 = Date.new(2018, 12, 25)
      expect(Date.current).to be > xmas_2018
      expect(Holiday.name(xmas_2018)).to be(Holiday::CHRISTMAS_DAY)
    end

    it "returns the right name for a holiday in the future" do
      xmas_2018 = Date.new(2018, 12, 25)
      allow(Date).to receive(:current).and_return(xmas_2018 - 5.days)
      expect(Date.current).to be < xmas_2018
      expect(Holiday.name(xmas_2018)).to be(Holiday::CHRISTMAS_DAY)
    end

    it "raises an error when the current day is not a holiday" do
      non_holiday = Date.new(2018, 7, 22)
      allow(Date).to receive(:current).and_return(non_holiday)
      expect { Holiday.name(non_holiday) }.to raise_error(ArgumentError)
    end
  end

end
