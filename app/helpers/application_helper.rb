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
