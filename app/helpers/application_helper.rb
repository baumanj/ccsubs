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
  NEW_YEARS_DAY = "New Year's Day"
  MARTIN_LUTHER_KING_JR_DAY = "Martin Luther King, Jr. Day"
  PRESIDENTS_DAY = "President's Day"
  MEMORIAL_DAY = "Memorial Day"
  INDEPENDENCE_DAY = "Independence Day"
  LABOR_DAY = "Labor Day"
  THANKSGIVING = "Thanksgiving"
  DAY_AFTER_THANKSGIVING = "Day after Thanksgiving"
  CHRISTMAS_EVE = "Christmas Eve"
  CHRISTMAS_DAY = "Christmas Day"
  NEW_YEARS_EVE = "New Year's Eve"

  NAMES = [
    NEW_YEARS_DAY,
    MARTIN_LUTHER_KING_JR_DAY,
    PRESIDENTS_DAY,
    MEMORIAL_DAY,
    INDEPENDENCE_DAY,
    LABOR_DAY,
    THANKSGIVING,
    DAY_AFTER_THANKSGIVING,
    CHRISTMAS_EVE,
    CHRISTMAS_DAY,
    NEW_YEARS_EVE,
  ]

  def self.to_name_and_date(date)
    "#{name(date)} (#{ShiftTime.date_to_s(date)})"
  end

  def self.next_date(name)
    case name
    when NEW_YEARS_DAY
      Date.next("January", 1)
    when MARTIN_LUTHER_KING_JR_DAY
      Date.nth_weekday_of(3, "Monday", "January")
    when PRESIDENTS_DAY
      Date.nth_weekday_of(3, "Monday", "February")
    when MEMORIAL_DAY
      Date.last_weekday_of("Monday", "May")
    when INDEPENDENCE_DAY
      Date.next("July", 4) # Should this be on the 4th or the observed day?
    when LABOR_DAY
      Date.nth_weekday_of(1, "Monday", "September")
    when THANKSGIVING
      Date.nth_weekday_of(4, "Thursday", "November")
    when DAY_AFTER_THANKSGIVING
      next_date("Thanksgiving").next_day
    when CHRISTMAS_EVE
      next_date("Christmas Day").prev_day
    when CHRISTMAS_DAY
      Date.next("December", 25)
    when NEW_YEARS_EVE
      Date.next("December", 31)
    end
  end

  def self.name(date)
    NAMES.find {|s| next_date(s) == date }
  end
end
