describe ShiftTime do

  it "returns the right next shift start" do

    dates = [
      { year: 2018, month:  3, day: 10 },
      { year: 2018, month:  3, day: 11 }, # DST begin
      { year: 2018, month:  3, day: 12 },
      { year: 2018, month:  6, day: 20 },
      { year: 2018, month: 11, day:  3 },
      { year: 2018, month: 11, day:  4 }, # DST end
      { year: 2018, month: 11, day:  5 },
    ]

    dates.each do |date|
      date = Date.new(date[:year], date[:month], date[:day])

    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour:  0, min: 59, sec: 59))).to \
    		                             eq(date.in_time_zone.change(hour:  8, min:  0, sec:  0))

    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour:  1, min:  0, sec:  0))).to \
    		                             eq(date.in_time_zone.change(hour:  8, min:  0, sec:  0))

    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour:  1, min:  0, sec:  1))).to \
    		                             eq(date.in_time_zone.change(hour:  8, min:  0, sec:  0))


    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour:  7, min: 59, sec: 59))).to \
    		                             eq(date.in_time_zone.change(hour:  8, min:  0, sec:  0))

    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour:  8, min:  0, sec:  0))).to \
    		                             eq(date.in_time_zone.change(hour: 12, min: 30, sec:  0))

    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour:  8, min:  0, sec:  1))).to \
    		                             eq(date.in_time_zone.change(hour: 12, min: 30, sec:  0))


    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour: 12, min: 29, sec: 59))).to \
    		                             eq(date.in_time_zone.change(hour: 12, min: 30, sec:  0))

    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour: 12, min: 30, sec:  0))).to \
    		                             eq(date.in_time_zone.change(hour: 17, min:  0, sec:  0))

    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour: 12, min: 30, sec:  1))).to \
    		                             eq(date.in_time_zone.change(hour: 17, min:  0, sec:  0))


    	expect(ShiftTime.next_shift_start(date.in_time_zone.change(hour: 20, min: 59, sec: 59))).to \
    		                             eq(date.in_time_zone.change(hour: 21, min:  0, sec:  0))

    	expect(ShiftTime.next_shift_start(date.         in_time_zone.change(hour:     21, min:  0, sec:  0))).to \
    		                             eq(date.tomorrow.in_time_zone.change(hour:  8, min:  0, sec:  0))

    	expect(ShiftTime.next_shift_start(date.         in_time_zone.change(hour:    21, min:  0, sec:  1))).to \
    		                             eq(date.tomorrow.in_time_zone.change(hour: 8, min:  0, sec:  0))
    end
  end
end
