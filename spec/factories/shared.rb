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

    # XXX remove this after FIRST_VALID_DATE is past
    def self.in_the_on_call_range(excluding: nil)
     in_date_range(OnCall::FIRST_VALID_DATE...(1.year.from_now.to_date), excluding: excluding)
    end

    def self.in_the_past_year(excluding: nil)
      in_date_range((1.year.ago.to_date)...(1.day.ago.to_date), excluding: excluding)
    end

    def self.in_date_range(range, excluding: nil)
      (range.to_a - [*excluding]).sample
    end
  end
end
