require 'rails_helper'

RSpec.describe OnCallReminder, type: :model do

  before { UserMailer.active_user = create(:recurring_shift_volunteer) }

  it "rejects a shift before the first valid date" do
    expect {
      date = OnCall::FIRST_VALID_DATE.prev_day
      create(:on_call_reminder, month: date.month, year: date.year)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  context "when there is a 1 month before reminder" do
    let(:templates) { [ OnCallReminder::Template['remind_on_call_signup', -1.month] ] }

    context "when no reminders have been sent" do
      it "does nothing when more than 1 month before the first valid date" do
        today = 1.month.ago(OnCall::FIRST_VALID_DATE).prev_day
        expect { OnCallReminder.send_reminders(templates: templates, today: today) }.to_not change { ActionMailer::Base.deliveries.count }
        expect(OnCallReminder.count).to eq(0)
      end

      it "sends a reminder for the current month if a month before or less" do
        today = 3.weeks.ago(OnCall::FIRST_VALID_DATE)
        expect(OnCallReminder.count).to eq(0)
        expect { OnCallReminder.send_reminders(templates: templates, today: today) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(OnCallReminder.count).to eq(1)
        expect(OnCallReminder.last.mailer_method).to eq('remind_on_call_signup')
        delivery = ActionMailer::Base.deliveries.last
        expect(delivery.to).to be_empty
        expect(delivery.bcc).to_not be_empty
        expect(delivery.subject).to include(OnCall::FIRST_VALID_DATE.strftime("%B"))
      end

      it "sends only one reminder per month" do
        expect(OnCallReminder.count).to eq(0)
        date_range = 1.year.since(OnCall::FIRST_VALID_DATE).all_year
        expected_num_reminders = date_range.map(&:month).uniq.size
        expect { date_range.each {|day| OnCallReminder.send_reminders(templates: templates, today: day) } }.to change { ActionMailer::Base.deliveries.count }.by(expected_num_reminders)
        expect(OnCallReminder.count).to eq(expected_num_reminders)
      end
    end
  end

  context "when there is a 1 month before reminder and a 2 weeks before reminder" do
    let(:templates) do
      [
        OnCallReminder::Template['remind_on_call_signup', -1.month],
        OnCallReminder::Template['remind_on_call_signup_again', -2.weeks],
      ]
    end

    context "when no reminders have been sent" do
      let!(:volunter_who_signed_up_before_first_reminder) { create(:recurring_shift_volunteer) }
      let!(:volunter_who_signed_up_after_first_reminder) { create(:recurring_shift_volunteer) }
      let!(:volunter_who_signed_up_after_second_reminder) { create(:recurring_shift_volunteer) }

      it "does nothing when more than 1 month before the first valid date" do
        today = 1.month.ago(OnCall::FIRST_VALID_DATE).prev_day
        expect { OnCallReminder.send_reminders(templates: templates, today: today) }.to_not change { ActionMailer::Base.deliveries.count }
        expect(OnCallReminder.count).to eq(0)
      end

      it "sends a reminder for the current month if a month before or less" do
        today = 3.weeks.ago(OnCall::FIRST_VALID_DATE)
        expect(OnCallReminder.count).to eq(0)
        expect { OnCallReminder.send_reminders(templates: templates, today: today) }.to change { ActionMailer::Base.deliveries.count }.by(1)
        expect(OnCallReminder.count).to eq(1)
        expect(OnCallReminder.last.mailer_method).to eq('remind_on_call_signup')
        delivery = ActionMailer::Base.deliveries.last
        expect(delivery.to).to be_empty
        expect(delivery.bcc).to_not be_empty
        expect(delivery.subject).to include(OnCall::FIRST_VALID_DATE.strftime("%B"))
      end

      it "reminds users only before they've signed up" do
        create(:on_call, date: OnCall::FIRST_VALID_DATE, user: volunter_who_signed_up_before_first_reminder)

        first_reminder = OnCallReminder.send_reminders(templates: templates, today: 3.weeks.ago(OnCall::FIRST_VALID_DATE))
        expect(first_reminder.users).to_not include(volunter_who_signed_up_before_first_reminder)
        expect(first_reminder.users).to include(volunter_who_signed_up_after_first_reminder, volunter_who_signed_up_after_second_reminder)

        create(:on_call, date: OnCall::FIRST_VALID_DATE.next_day, user: volunter_who_signed_up_after_first_reminder)

        second_reminder = OnCallReminder.send_reminders(templates: templates, today: 1.week.ago(OnCall::FIRST_VALID_DATE))
        expect(second_reminder.users).to_not include(volunter_who_signed_up_before_first_reminder, volunter_who_signed_up_after_first_reminder)
        expect(second_reminder.users).to include(volunter_who_signed_up_after_second_reminder)
      end

      it "sends two reminders per month" do
        expect(OnCallReminder.count).to eq(0)
        date_range = 1.year.since(OnCall::FIRST_VALID_DATE).all_year
        expected_num_reminders = 2 * date_range.map(&:month).uniq.size
        expect { date_range.each {|day| OnCallReminder.send_reminders(templates: templates, today: day) } }.to change { ActionMailer::Base.deliveries.count }.by(expected_num_reminders)
        expect(OnCallReminder.count).to eq(expected_num_reminders)
      end
    end
  end
end
