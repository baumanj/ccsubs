module Faker
  class Date
    def self.unique_in_the_next_year
      @previously_selected ||= []
      @previously_selected << in_the_next_year(excluding: @previously_selected)
      @previously_selected.last
    end

    def self.in_the_next_year(excluding: nil)
      dates_in_next_year = ((1.day.from_now.to_date)...(1.year.from_now.to_date)).to_a
      (dates_in_next_year - [*excluding]).sample
    end
  end
end

FactoryGirl.define do
  factory :request do
    user
    date { Faker::Date.unique_in_the_next_year }
    shift { Request.shifts.keys.sample }

    factory :sent_offer_request, class: Request do
      transient do
        sent_offer_request_date { Faker::Date.unique_in_the_next_year }
        sent_offer_request_shift { Request.shifts.keys.sample }
        received_offer_request_date { Faker::Date.unique_in_the_next_year }
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

      factory :received_offer_request do
        after(:build) do |r|
          r.state, r.fulfilling_swap.state = r.fulfilling_swap.state, r.state
        end
      end

      factory :fulfilled_request do
        after(:build) do |r|
          [r, r.fulfilling_swap].each do |s|
            s.state = :fulfilled
            s.availability.free = false
          end
        end
      end
    end
  end
end