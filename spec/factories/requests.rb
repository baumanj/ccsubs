class Faker::Date
  def between_excluding(from, to, exclude: nil)
    loop do
        d = super(from, to)
        break unless [*x].includes?(d)
      end
    end
  end
end

FactoryGirl.define do
  factory :request do
	user
    date Faker::Date.between(1.day.from_now, 1.year.from_now)
    shift Request.shifts.values.sample
  end

  factory :sent_offer_requst, class: Request do
    user
    date Faker::Date.between(1.day.from_now, 1.year.from_now)
    shift Request.shifts.values.sample
    state :sent_offer
    availability { create(:availability, date: date, shift: shift) }
    fulfilling_swap do
      create(:request
        user: availability.user, state: :received_request,
        date: Faker::Date.between_excluding(1.day.from_now, 1.year.from_now, date)
        availability: create(:availability, date: other_date)
      )
    end
  end
end