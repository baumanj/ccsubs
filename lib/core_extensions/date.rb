class Date

  def self.next(month_name, day_number, after_date=self.current)
    month_index = MONTHNAMES.index(month_name)
    date = after_date + 1
    date += 1 until date.mon == month_index && date.day == day_number
    date
  end

  def self.nth_weekday_of(n, day_name, month_name, after_date=self.current)
    weekday_index = nil
    month_index = MONTHNAMES.index(month_name)
    date = after_date.beginning_of_year
    max_date = if after_date.mon < month_index
      after_date.end_of_year
    else
      after_date.next_year.end_of_month
    end

    while date < max_date
      if date.mon == month_index
        weekday_index = 0 if date.day == 1
        if date.send("#{day_name.downcase}?")
          weekday_index += 1
          return date if weekday_index == n && date > after_date
        end
      end

      date += 1
    end

    raise(ArgumentError, "#{month_name} has fewer than #{n} #{day_name}s")
  end

  def self.last_weekday_of(day_name, month_name, after_date=self.current)
    month_index = MONTHNAMES.index(month_name)

    # find this year's
    date = after_date.change(month: month_index).end_of_month

    while date > after_date
      return date if date.send("#{day_name.downcase}?")
      date -= 1
    end

    date = after_date.change(month: month_index).advance(years: 1).end_of_month

    while date > after_date
      return date if date.send("#{day_name.downcase}?")
      date -= 1
    end

    raise(ArgumentError, "#{month_name} has no #{day_name}s")
  end

end
