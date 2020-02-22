module Faker
  class Date
    def self.unique(date_method)
      @previously_selected ||= Hash.new {|hash, key| hash[key] = [] }

      if (unique_date = send(date_method, excluding: @previously_selected[date_method]))
        @previously_selected[date_method] << unique_date
      else
        # If we've used all the ones in the range, recycle oldest
        @previously_selected[date_method].rotate!
      end

      @previously_selected[date_method].last
    end

    def self.in_the_next_year(excluding: nil)
      in_date_range((1.day.from_now.to_date)...(1.year.from_now.to_date), excluding: excluding)
    end

    def self.in_the_next_year_minus_one_day(excluding: nil)
      in_date_range((1.day.from_now.to_date)...(1.year.from_now.to_date.prev_day), excluding: excluding)
    end

    def self.in_the_next_year_post_location_change(excluding: nil)
      start = [1.day.from_now.to_date, ShiftTime::LOCATION_CHANGE_DATE].max
      end_ = [1.year.from_now.to_date, 1.year.from_now(start).to_date].min
      in_date_range(start...end_, excluding: excluding)
    end

    def self.in_the_past_year(excluding: nil)
      in_date_range((1.year.ago.to_date)...(1.day.ago.to_date), excluding: excluding)
    end

    def self.in_date_range(range, excluding: nil)
      (range.to_a - [*excluding]).sample
    end

    def self.holiday_in_next_year(excluding: nil)
      (Holiday::dates_in_coming_year - [*excluding]).sample
    end
  end
end
