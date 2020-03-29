require_relative 'shared'

date_in_the_past_year = proc do
  to_create {|instance| instance.save(validate: false) }
  date { Faker::Date.unique(:in_the_past_year) }
end

FactoryBot.define do
  factory :request, aliases: [:seeking_offers_request] do
    user { build(:user) } # To satifsy attributes_for
    date { Faker::Date.unique(:in_the_next_year) }
    shift { Request.shifts.keys.sample }
    location { user.location_for(date) }

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
      state {:sent_offer}
      availability {
        build(:availability,
          user: build(:user, location: user.location),
          date: date,
          shift: shift
        )
      }
      fulfilling_swap do
        build(:request,
          user: availability.user, state: :received_offer,
          date: received_offer_request_date,
          shift: received_offer_request_shift,
          location: availability.user.location_for(received_offer_request_date),
          availability: build(:availability, date: received_offer_request_date, shift: received_offer_request_shift, user: user)
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