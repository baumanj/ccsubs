require 'rails_helper'

RSpec.describe SignupReminder, type: :model do

  before { UserMailer.active_user = create(:recurring_shift_volunteer) }

  it "rejects a shift before the first valid date" do
    expect {
      date = OnCall::FIRST_VALID_DATE.prev_day
      create(:signup_reminder, month: date.month, year: date.year, day: date.day, event_type: :on_call)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  context "when there is a 1 month before reminder" do
    let(:templates) { [ SignupReminder::Template['remind_on_call_signup', -1.month] ] }

    context "when no reminders have been sent" do
      it "does nothing when more than 1 month before the first valid date" do
        today = 1.month.ago(OnCall::FIRST_VALID_DATE).prev_day
        expect { SignupReminder.send_for_on_call(templates: templates, today: today) }.to_not change { ActionMailer::Base.deliveries.count }
        expect(SignupReminder.count).to eq(0)
      end

      it "sends a reminder for the current month if a month before or less" do
        today = 3.weeks.ago(OnCall::FIRST_VALID_DATE)
        expect(SignupReminder.count).to eq(0)
        expect { SignupReminder.send_for_on_call(templates: templates, today: today) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(SignupReminder.count).to eq(1)
        expect(SignupReminder.last.mailer_method).to eq('remind_on_call_signup')
        delivery = ActionMailer::Base.deliveries.last
        expect(delivery.to).to be_empty
        expect(delivery.bcc).to_not be_empty
        expect(delivery.subject).to include(OnCall::FIRST_VALID_DATE.strftime("%B"))
      end

      it "sends only one reminder per month" do
        expect(SignupReminder.count).to eq(0)
        date_range = 1.year.since(OnCall::FIRST_VALID_DATE).all_year
        expected_num_reminders = date_range.map(&:month).uniq.size
        expect { date_range.each {|day| SignupReminder.send_for_on_call(templates: templates, today: day) } }.to change { ActionMailer::Base.deliveries.count }.by(expected_num_reminders)
        expect(SignupReminder.count).to eq(expected_num_reminders)
      end
    end
  end

  context "when there is a 1 month before reminder and a 2 weeks before reminder" do
    let(:templates) do
      [
        SignupReminder::Template['remind_on_call_signup', -1.month],
        SignupReminder::Template['remind_on_call_signup_again', -2.weeks],
      ]
    end

    context "when no reminders have been sent" do
      let!(:volunter_who_signed_up_before_first_reminder) { create(:recurring_shift_volunteer) }
      let!(:volunter_who_signed_up_after_first_reminder) { create(:recurring_shift_volunteer) }
      let!(:volunter_who_signed_up_after_second_reminder) { create(:recurring_shift_volunteer) }

      it "does nothing when more than 1 month before the first valid date" do
        today = 1.month.ago(OnCall::FIRST_VALID_DATE).prev_day
        expect { SignupReminder.send_for_on_call(templates: templates, today: today) }.to_not change { ActionMailer::Base.deliveries.count }
        expect(SignupReminder.count).to eq(0)
      end

      it "sends a reminder for the current month if a month before or less" do
        today = 3.weeks.ago(OnCall::FIRST_VALID_DATE)
        expect(SignupReminder.count).to eq(0)
        expect { SignupReminder.send_for_on_call(templates: templates, today: today) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(SignupReminder.count).to eq(1)
        expect(SignupReminder.last.mailer_method).to eq('remind_on_call_signup')
        delivery = ActionMailer::Base.deliveries.last
        expect(delivery.to).to be_empty
        expect(delivery.bcc).to_not be_empty
        expect(delivery.subject).to include(OnCall::FIRST_VALID_DATE.strftime("%B"))
      end

      it "reminds users only before they've signed up" do
        first_of_next_month = Date.today.next_month.at_beginning_of_month
        create(:on_call, date: first_of_next_month, user: volunter_who_signed_up_before_first_reminder)

        first_reminder = SignupReminder.send_for_on_call(templates: templates, today: 3.weeks.ago(first_of_next_month))
        expect(first_reminder.users).to_not include(volunter_who_signed_up_before_first_reminder)
        expect(first_reminder.users).to include(volunter_who_signed_up_after_first_reminder, volunter_who_signed_up_after_second_reminder)

        create(:on_call, date: first_of_next_month.next_day, user: volunter_who_signed_up_after_first_reminder)

        second_reminder = SignupReminder.send_for_on_call(templates: templates, today: 1.week.ago(first_of_next_month))
        expect(second_reminder.users).to_not include(volunter_who_signed_up_before_first_reminder, volunter_who_signed_up_after_first_reminder)
        expect(second_reminder.users).to include(volunter_who_signed_up_after_second_reminder)
      end

      it "sends two reminders per month" do
        expect(SignupReminder.count).to eq(0)
        date_range = 1.year.since(OnCall::FIRST_VALID_DATE).all_year
        expected_num_reminders = 2 * date_range.map(&:month).uniq.size
        expect { date_range.each {|day| SignupReminder.send_for_on_call(templates: templates, today: day) } }.to change { ActionMailer::Base.deliveries.count }.by(expected_num_reminders)
        expect(SignupReminder.count).to eq(expected_num_reminders)
      end
    end
  end
end
