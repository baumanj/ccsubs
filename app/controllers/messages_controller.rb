class MessagesController < ApplicationController
  before_action :require_admin

  def new
  end

  def deliver
    recipients = User.all
    mailer.all_hands_email(recipients, params['subject'], params['body']).deliver
    flash[:success] = "Sent '#{params['subject']}' email to #{recipients.count} users"
    redirect_to messages_new_path
  end
end
