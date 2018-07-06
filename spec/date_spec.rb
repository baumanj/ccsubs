describe Date do

  it "returns the correct next date" do
    expect(Date.next("July", 4, Date.new(2018, 7, 5))).to eq(Date.new(2019, 7, 4))
  end

end
