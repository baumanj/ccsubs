module Faker
  class Date
    def self.unique(date_method)
      @previously_selected ||= []
      @previously_selected << send(date_method, excluding: @previously_selected)
      @previously_selected.last
    end

    def self.in_the_next_year(excluding: nil)
     in_date_range((1.day.from_now.to_date)...(1.year.from_now.to_date), excluding: excluding)
    end

    def self.in_the_past_year(excluding: nil)
      in_date_range((1.year.ago.to_date)...(1.day.ago.to_date), excluding: excluding)
    end

    def self.in_date_range(range, excluding: nil)
      (range.to_a - [*excluding]).sample
    end
  end
end

date_in_the_past_year = proc do
  to_create {|instance| instance.save(validate: false) }
  date { Faker::Date.unique(:in_the_past_year) }
end

FactoryGirl.define do
  factory :request, aliases: [:seeking_offers_request] do
    user
    date { Faker::Date.unique(:in_the_next_year) }
    shift { Request.shifts.keys.sample }

    factory :past_request, aliases: [:past_seeking_offers_request], &date_in_the_past_year

    factory :sent_offer_request, class: Request do
      transient do
        sent_offer_request_date { Faker::Date.unique(:in_the_next_year) }
        sent_offer_request_shift { Request.shifts.keys.sample }
        received_offer_request_date { Faker::Date.unique(:in_the_next_year) }
        received_offer_request_shift { Request.shifts.keys.sample }
      end

      date { sent_offer_request_date }
      shift { sent_offer_request_shift }
      state :sent_offer
      availability { build(:availability, date: date, shift: shift) }
      fulfilling_swap do
        build(:request,
          user: availability.user, state: :received_offer,
          date: received_offer_request_date,
          shift: received_offer_request_shift,
          availability: build(:availability, date: received_offer_request_date, shift: received_offer_request_shift)
        )
      end
      after(:build) {|r| r.fulfilling_swap.fulfilling_swap = r }

      factory :past_sent_offer_request, &date_in_the_past_year

      factory :received_offer_request do
        after(:build) do |r|
          r.state, r.fulfilling_swap.state = r.fulfilling_swap.state, r.state
        end

        factory :past_received_offer_request, &date_in_the_past_year
      end

      factory :fulfilled_request do
        after(:build) do |r|
          [r, r.fulfilling_swap].each do |s|
            s.state = :fulfilled
            s.availability.free = false
          end
        end

        factory :past_fulfilled_request, &date_in_the_past_year
      end
    end
  end
end