class Date

  def self.next(month_name, day_number, after_date=self.current)
    month_index = MONTHNAMES.index(month_name)
    date = after_date + 1
    date += 1 until date.mon == month_index && date.day == day_number
    date
  end

  def self.nth_weekday_of(n, day_name, month_name)
    month_index = MONTHNAMES.index(month_name)
    date = self.current

    until date.mon == month_index
      date = date.advance(months: 1)
    end

    date = date.change(day: 1)

    until date.send("#{day_name.downcase}?")
      date = date.advance(days: 1)
    end

    date.advance(weeks: n - 1)
  end

  def self.last_weekday_of(day_name, month_name)
    month_index = MONTHNAMES.index(month_name)
    date = self.current

    until date.mon == month_index
      date = date.advance(months: 1)
    end

    date = date.change(day: 1)

    until date.send("#{day_name.downcase}?")
      date = date.advance(days: 1)
    end

    while date.advance(weeks: 1).mon == month_index
      date = date.advance(weeks: 1)
    end

    date
  end

end
