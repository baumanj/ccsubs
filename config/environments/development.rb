Ccsubs::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  config.action_mailer.raise_delivery_errors = true
  host = 'localhost:3000'
  config.action_mailer.default_url_options = { host: host }
  config.action_mailer.delivery_method = :smtp
  user_name = Bundler.with_clean_env { `heroku config:get SENDGRID_USERNAME --app ccsubs`.strip }
  password = Bundler.with_clean_env { `heroku config:get SENDGRID_PASSWORD --app ccsubs`.strip }
  config.action_mailer.smtp_settings = {
    address: 'smtp.sendgrid.net',
    port: '587',
    domain: 'heroku.com',
    authentication: 'plain',
#    enable_starttls_auto: true,
    user_name: user_name,
    password: password
  }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Stop the development & test logs from taking up to much space
  # https://stackoverflow.com/questions/7784057/ruby-on-rails-log-file-size-too-large/37499682#37499682
  config.logger = ActiveSupport::Logger.new(config.paths['log'].first, 1, 50.megabytes)
end
