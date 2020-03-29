class UserMailer < ActionMailer::Base
  include ApplicationHelper

  VOLUNTEER_SERVICES = if Rails.env.production?
    "ccsubs <volunteerservices@crisisconnections.org>"
  else
    "baumanj+volunteerservices@gmail.com"
  end
  default from: VOLUNTEER_SERVICES

  def self.active_user=(user)
    @@active_user = user
  end

  # Never send email to real addresses unless running in production on heroku
  # - In development or locally-run production, always send to @shumi.org
  # - In test, no emails are actually sent, but use the real headers
  # If not running the main app (e.g. ccsubs-preview) send mail to the current user instead of the
  # regular recipient, but keep the name of the real recipient to indicate who would receive what.
  def mail(headers)
    if !Rails.env.development? && !local_production?
      headers[:subject] = "[#{ENV['APP_NAME']}] #{headers[:subject]}"
    end

    [:to, :cc, :bcc].each do |header_name|
      headers[header_name] = [*headers[header_name]].map {|x| get_address(x) }
    end

    super
  end

  def all_hands_email(users, subject, body)
    mail(reply_to: 'do-not-email-call-206-461-3210x1@crisisconnections.org', bcc: users, subject: subject) do |format|
      format.text { render plain: body }
    end
  end

  def alert(body)
    alert_recipient(User.first, "Alert!", body)
  end

  def alert_sub_only_holiday(holiday_request)
    body =<<-EOF
#{holiday_request.fulfilling_user} <#{holiday_request.fulfilling_user.email}> has taken
the request
that was for
#{Holiday.to_name_and_date(holiday_request.date)} #{holiday_request.shift}

and which
you were probably
saving
for regular volunteers

Applaud them
they were generous
so sweet
and so cool
    EOF
    alert_recipient(VOLUNTEER_SERVICES, "Sub-only hoilday fulfillment", body)
  end

  def confirm_email(user)
    @user = user
    mail to: user, subject: "Confirm your ccsubs email"
  end

  def notify_potential_matches(req, half_matching_requests)
    @req = req
    @available_user = half_matching_requests.first.user
    @potential_swaps = half_matching_requests
    mail to: @req.user,
         subject: "Sub/Swap #{@req}: potential match found"
  end

  def notify_full_matches(req, matching_requests)
    @req = req
    @available_user = matching_requests.first.user
    @suggested_swaps = matching_requests
    mail to: @req.user,
         subject: "Sub/Swap #{@req}: match found! [ACTION REQUIRED]"
  end

  def remind_holiday(req, fulfilling_user)
    @req = req
    @fulfilling_user = fulfilling_user
    attach_ical @req.to_ical(summary: "Crisis Connections Holiday Shift", description: "You agreed to cover this holiday shift because you're awesome")
    mail to: @fulfilling_user,
         subject: "#{@req}"
  end

  def notify_sub(req, fulfilling_user)
    @req = req
    @fulfilling_user = fulfilling_user
    mail to: @req.user,
         subject: "Sub/Swap #{@req}: #{@fulfilling_user} subbing for #{@user}",
         cc: VOLUNTEER_SERVICES
  end

  def remind_sub(req, fulfilling_user)
    @req = req
    @fulfilling_user = fulfilling_user
    attach_ical @req.to_ical(summary: "Crisis Connections Shift", description: "You agreed to sub for this shift because you're awesome")
    mail to: @fulfilling_user,
         subject: "Sub/Swap #{@req}: you have agreed to sub"
  end

  def notify_swap_offer(from: nil, to: nil)
    raise ArgumentError if from.nil? || to.nil? # need ruby 2.1
    @received_offer_request = to
    @sent_offer_request = from
    mail to: @received_offer_request.user,
         subject: "Sub/Swap #{@received_offer_request}: swap offered! [ACTION REQUIRED]"
  end

  def send_unresponded_offer_nag(req)
    @req = req
    @nagee = @req.user
    @offerer = @req.fulfilling_user
    mail to: @nagee,
         subject: "Sub/Swap #{@req}: swap offer will expire soon!",
         cc: VOLUNTEER_SERVICES
  end

  def notify_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_user
    attach_ical @req.to_ical(summary: "Crisis Connections Shift", description: "You agreed to cover this shift in exchange for #{@req.fulfilling_swap}")
    mail to: @acceptee,
         subject: "Sub/Swap #{@req}: #{@acceptee} swapping for #{@accepter} covering #{@req.fulfilling_swap}",
         cc: VOLUNTEER_SERVICES
  end

  def remind_swap_accept(req)
    @req = req
    @accepter = req.user
    @acceptee = req.fulfilling_user
    attach_ical @req.fulfilling_swap.to_ical(summary: "Crisis Connections Shift", description: "You agreed to cover this shift in exchange for #{@req}")
    mail to: @accepter,
         subject: "Sub/Swap #{@req}: swap from #{@acceptee} accepted for #{@req.fulfilling_swap}"
  end

  def confirm_on_call_signup(on_call)
    @description = "We only call you in if a regular shift member is sick or has an emergency but need to count on your help if that happens. If you have not received a call from the phone room 45 minutes into the on-call shift time you signed up for, you are free to assume that you are not needed!"
    @on_call = on_call
    attach_ical @on_call.to_ical(summary: "Crisis Connections on-call", description: @description)
    mail to: @on_call.user,
         subject: "On-call signup for #{@on_call} confirmed"
  end

  def notify_swap_decline(decliners_request: req, offerers_request: offer_req)
    @decliners_request = decliners_request
    @decliner = decliners_request.user
    @declinee = offerers_request.user
    mail to: @declinee,
         subject: "Sub/Swap #{offerers_request}: swap with #{@decliner} declined "
  end

  def remind_on_call_signup(users, date)
    @date_string = date.strftime("%B")
    @url = edit_on_call_url(date)
    mail bcc: users,
         subject: "On-call signup reminder for #{@date_string} [ACTION REQUIRED]"
  end

  def remind_on_call_signup_again(users, date)
    @date_string = date.strftime("%B")
    @url = edit_on_call_url(date)
    mail bcc: users,
         subject: "On-call signup second reminder for #{@date_string} [ACTION REQUIRED]"
  end

  def remind_holiday_signup(users, date)
    remind_holiday_signup_common(users, date)
    mail bcc: users,
         subject: "Holiday signup reminder for #{@holiday} [ACTION REQUIRED]"
  end

  def remind_holiday_signup_again(users, date)
    remind_holiday_signup_common(users, date)
    mail bcc: users,
         subject: "Holiday signup second reminder for #{@holiday} [ACTION REQUIRED]"
  end

  def reset_password(user)
    @user = user
    mail to: user, subject: "Reset your ccsubs password"
  end

  private

    def alert_recipient(recipient, subject, body)
      mail(to: recipient, subject: subject) do |format|
        format.text { render plain: body }
      end
    end

    def remind_holiday_signup_common(users, date)
      @holiday = Holiday.name(date)
      @shifts = HolidayRequest.where(date: date).group_by(&:shift).keys
      @url = holiday_requests_url
      @asterisk_text = if 1.year.ago(date) < HolidayRequest::FIRST_VALID_DATE
        "* Holiday sign-ups moved online starting #{HolidayRequest::FIRST_VALID_DATE}. Paper signups before then are unknown to the system, so if you are receiving this reminder despite having worked a holiday shift between #{1.year.ago(date)} and #{HolidayRequest::FIRST_VALID_DATE}, you can ignore this or sign up for your next holiday shift and you won't be notified again."
      end
    end

    def attach_ical(ical)
      attachments['ccsubs.ics'] = { mime_type: 'text/calendar', content: ical }
    end

    def get_address(input)
      if input.class == String
        email = input
        name = nil
      else
        email = input.email
        name = input.name
      end

      if Rails.env.development? || local_production?
        email = "jon.#{email.sub('@', '.at.')}@shumi.org"
      elsif ENV['APP_NAME'] == 'ccsubs' || Rails.env.test?
        email = email
      elsif defined?(@@active_user) && !@@active_user.nil?
        email = @@active_user.email
      else
        email = "jon.ccsubs_fallback@shumi.org"
      end

      name ? "\"#{name}\" <#{email}>" : email
    end

end
