class MessagesController < ApplicationController
  before_action :require_admin

  def new
  end

  def deliver
    recipients = User.all
    # Saw EOFError when sending to over 200/email, so slice into smaller chunks
    recipients.each_slice(100) do |slice|
      mailer.all_hands_email(slice, params['subject'], params['body']).deliver
    end
    flash[:success] = "Sent '#{params['subject']}' email to #{recipients.count} users"
    redirect_to messages_new_path
  end
end
