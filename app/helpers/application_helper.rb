module ApplicationHelper
  FLASH_KEY_TO_BOOTSTRAP_CLASS = { 'success' => 'success', 
                                   'notice'  => 'info',
                                   'alert'   => 'warning',
                                   'error'   => 'danger' }
  def flash_class(key)
    FLASH_KEY_TO_BOOTSTRAP_CLASS[key]
  end

  def mailer
    UserMailer.active_user = current_user
    UserMailer
  end

  def app_name
    ENV['APP_NAME'] || "#{Rails.env} CCsubs"
  end

  def heroku?
    !ENV['DYNO'].nil?
  end

  def local_production?
    Rails.env.production? && !heroku?
  end

  def staging?
    heroku? && ENV['APP_NAME'] == "ccsubs-preview"
  end
end

module Holiday
  NAMES = [
    "New Year's Day",
    "Martin Luther King, Jr. Day",
    "President's Day",
    "Memorial Day",
    "Independence Day",
    "Labor Day",
    "Day before Thanksgiving",
    "Veterans Day",
    "Thanksgiving",
    "Christmas Day",
    "New Year's Eve",
  ]

  def self.to_name_and_date(date)
    "#{name(date)} (#{ShiftTime.date_to_s(date)})"
  end

  def self.next_date(name)
    case name
    when "New Year's Day"
      Date.next("January", 1)
    when "Martin Luther King, Jr. Day"
      Date.nth_weekday_of(3, "Monday", "January")
    when "President's Day"
      Date.nth_weekday_of(3, "Monday", "February")
    when "Memorial Day"
      Date.last_weekday_of("Monday", "May")
    when "Independence Day"
      Date.next("July", 4) # Should this be on the 4th or the observed day?
    when "Labor Day"
      Date.nth_weekday_of(1, "Monday", "September")
    when "Day before Thanksgiving"
      next_date("Thanksgiving").prev_day
    when "Thanksgiving"
      Date.nth_weekday_of(4, "Thursday", "November")
    when "Veterans Day"
      Date.next("November", 11)
    when "Christmas Day"
      Date.next("December", 25)
    when "New Year's Eve"
      Date.next("December", 31)
    end
  end

  def self.name(date)
    NAMES.find {|n| next_date(n) == date }
  end
end
