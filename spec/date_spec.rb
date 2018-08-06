describe Date do

  it "returns the correct next date" do
    expect(Date.next("July", 4, Date.new(2018, 7, 5))).to eq(Date.new(2019, 7, 4))
  end

  it "returns the correct nth weekday of month" do
    expect(Date.nth_weekday_of(4, "Friday", "September", Date.new(2018, 9, 27))).to eq(Date.new(2018, 9, 28))
    expect(Date.nth_weekday_of(4, "Friday", "September", Date.new(2018, 9, 28))).to eq(Date.new(2019, 9, 27))
    expect(Date.nth_weekday_of(3, "Monday", "February", Date.new(2018, 2, 19))).to eq(Date.new(2019, 2, 18))
  end

  it "returns the correct last weekday of month" do
    expect(Date.last_weekday_of("Monday", "May", Date.new(2018, 5, 27))).to eq(Date.new(2018, 5, 28))
    expect(Date.last_weekday_of("Monday", "May", Date.new(2018, 5, 28))).to eq(Date.new(2019, 5, 27))
  end

  it "gives an error if there isn't a valid nth weekday of month" do
    expect { Date.nth_weekday_of(5, "Friday", "September", Date.new(2018, 1, 1)) }.to raise_error(ArgumentError)
    expect { Date.nth_weekday_of(5, "Thursday", "March", Date.new(2018, 3, 29)) }.to raise_error(ArgumentError)
  end
end
