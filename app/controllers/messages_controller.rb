class MessagesController < ApplicationController
  before_action :require_staff_or_admin

  def new
    @message = Message.new
  end

  def deliver
    @message = Message.new(message_params)
    if @message.save
      unavailable_users =
        Availability.where_shifttime(@message).where(free: false).map(&:user) +
        Request.where_shifttime(@message).map(&:user)
        # TODO add users for whom this is their default shift
      recipients = User.where(disabled: false) - unavailable_users
      mailer.all_hands_email(recipients, @message.subject, @message.body_with_boilerplate).deliver_now
      flash[:success] = "Sent '#{@message.subject}' email to #{recipients.count} users"
      flash[:success] += " (excluding #{unavailable_users.count} who are unavailable)" if unavailable_users.any?
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
