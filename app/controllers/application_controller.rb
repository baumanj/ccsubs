class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  include ApplicationHelper
  include SessionsHelper

  before_action do
    unless Rails.env.test?
      Rack::MiniProfiler.authorize_request unless heroku? && !staging?
    end
  end
end
