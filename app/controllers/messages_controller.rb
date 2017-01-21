class MessagesController < ApplicationController
  before_action :require_admin

  def new
    @message = Message.new
  end

  def deliver
    @message = Message.new(message_params)
    # raise
    if @message.save
      recipients = User.where(disabled: false)
      mailer.all_hands_email(recipients, @message.subject, @message.body_with_boilerplate).deliver
      flash[:success] = "Sent '#{@message.subject}' email to #{recipients.count} users"
      redirect_to messages_new_path
    else
      flash.now[:error] = "Message couldn't be created. Please check the errors and retry."
      @errors = @message.errors
      render 'new'
    end
  end

  private

    def message_params
      params.require(:message).permit([:date, :shift, :body])
    end

end
