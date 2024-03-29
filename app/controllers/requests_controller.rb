class RequestsController < ApplicationController
  before_action :require_confirmed_email
  before_action :find_request, except: [:new, :create, :index, :owned_index, :fulfilled, :pending]
  before_action :check_owner, except: [:new, :create, :offer_sub, :show, :index, :owned_index, :fulfilled, :pending]
  before_action :check_editable, except: [:new, :create, :show, :index, :owned_index, :fulfilled, :pending]

  def new
    @request = Request.new(params.permit(:date, :shift))
  end

  def create
    redirect_to new_request_path
    # @request = Request.new(request_params)
    # @request.user ||= current_user

    # # This is a bit awkward, but necessary as long as location varies by date
    # if @request.date.nil?
    #   @request.errors.add(:date, "can't be blank")
    # else
    #   @request.location = @request.user.location_for(@request.date)
    # end

    # if @request.location && @request.save
    #   redirect_to @request
    # else
    #   flash.now[:error] = "Request couldn't be created. Please check the errors and retry."
    #   @errors = @request.errors
    #   render 'new'
    # end
  end

  def show
    case @request.state
    when 'seeking_offers'
      if @request.user == current_user
        @requests_to_swap_with = @request.offerable_swaps
        if @requests_to_swap_with.any?
          @availabilities_for_requests_to_swap_with = @request.user.availabilities_for(@requests_to_swap_with)
          render 'choose_swap'
        else
          if params[:from] == 'notification'
            flash.now[:notice] = "Sorry, that shift is no longer accepting swap offers"
          end

          if @request.uncertain_avail.any?
            @suggested_availabilities = DefaultAvailability.apply(@request.user.availabilities_for(:potential_matches))
            render 'specify_availability'
          end
        end
      elsif @conflict = current_user.conflict_for(@request)
        # Nothing to do, @conflict is already assigned
      else
        @requests_to_swap_with = current_user.offerable_swaps(@request)
        if @requests_to_swap_with.any?
          @availabilities_for_requests_to_swap_with = current_user.availabilities_for(@requests_to_swap_with)
        end
        # What about potential matches?
      end
    when 'received_offer', 'sent_offer', 'fulfilled'
      # Nothing extra to do
    else
      flash.now[:error] = "Request unexpectedly in #{@request.state} state"
    end
  end

  def update
    if params[:request_to_swap_with_id]
      set_fulfilling_swap
    else
      case params[:offer_response]
      when 'accept'
        accept_swap_offer
      when 'decline'
        decline_swap_offer
      else
        flash[:error] = "Unexpected offer response: #{params[:offer_response]}"
      end
    end

    redirect_to @request
  end

  def offer_sub
    if @request.is_a? HolidayRequest
      redirect_to holiday_requests_path
      return
    elsif @request.fulfill_by_sub(current_user)
      if @request.is_a? HolidayRequest
        mailer.remind_holiday(@request, current_user).deliver_now
        flash[:success] = "Thanks! We sent you an email reminder with the details."
      else
        emails = [mailer.notify_sub(@request, current_user),
                  mailer.remind_sub(@request, current_user)]
        emails.each &:deliver_now
        flash[:success] = "Thanks! We sent #{@request.user} an email to let them know the good news."
      end
    else
      flash[:error] = @request.errors.full_messages.join(". ")
    end

    redirect_to @request
  end

  def index
    @requests = Request.active
  end

  def owned_index
    @owner = User.find(user_id)
    @requests = params[:past] ? @owner.requests.past : @owner.requests.on_or_after(Date.today)
  end

  def fulfilled
    @requests = Request.including_holidays.on_or_after(Date.today).fulfilled
    @today = @requests.where(date: Date.today)
    @this_week = @requests.where(date: (Date.today + 1)..(Date.today + 7))
    @later = @requests.where(date: (Date.today + 8)..(Date.today + 1000))
  end

  def pending
    @requests = current_user.requests.pending
    if @requests.count == 1
      redirect_to @requests.first
    end
  end

  def destroy
    if (@request.seeking_offers? || current_user_can_edit?(@request)) && @request.destroy
      flash[:success] = "Request deleted: #{@request}"
      redirect_to params[:redirect_to] || :back
    else
      flash[:error] = "Request cannot be deleted in the #{@request.state} state"
      redirect_to @request
    end
  end

  private

    def set_fulfilling_swap
      request_to_swap_with = Request.find_by(id: params[:request_to_swap_with_id])
      if request_to_swap_with && @request.send_swap_offer_to(request_to_swap_with)
        notify_swap_offered
      elsif request_to_swap_with.nil?
        flash[:error] = "Request to swap with could not be found; it may have just been deleted"
      elsif @request.fulfilling_user && @request.fulfilling_user != request_to_swap_with.user
        flash[:error] = "Sorry, #{@request.fulfilling_user} beat you to it"
      else
        flash[:error] = "Something went wrong! We couldn't make the offer. #{@request.errors.full_messages.join(". ")}"
      end
    end

    def accept_swap_offer
      if @request.accept_pending_swap
        notify_swap_accepted
      elsif @request.fulfilling_swap.nil?
        flash[:error] = "There was no pending swap offer to accept"
      else
        flash[:error] = "Something went wrong! We couldn't accept the swap. #{@request.errors.full_messages.join(". ")}"
      end
    end

    def decline_swap_offer
      request_we_declined_to_swap_for = @request.fulfilling_swap
      if @request.decline_pending_swap
        notify_swap_declined(request_we_declined_to_swap_for)
      elsif @request.fulfilling_swap.nil?
        flash[:error] = "There was no pending swap offer to decline"
      else
        flash[:error] = "Something went wrong! We couldn't decline the swap. #{@request.errors.full_messages.join(". ")}"
      end
    end

    def user_id
      (current_user.admin? && params[:user_id]) || current_user.id
    end

    def notify_swap_offered
      mailer.notify_swap_offer(from: @request, to: @request.fulfilling_swap).deliver_now
      flash[:success] = "We sent #{@request.fulfilling_user} an email to let them know about your offer"
    end

    def notify_swap_accepted
      [mailer.notify_swap_accept(@request), mailer.remind_swap_accept(@request)].each &:deliver_now
      flash[:success] = "We sent #{@request.fulfilling_user} an email to let them know you accepted"
    end

    def notify_swap_declined(offer_request)
      mailer.notify_swap_decline(decliners_request: @request, offerers_request: offer_request).deliver_now
      flash[:success] = "We sent #{offer_request.user} an email to let them know you declined"
    end

    def find_request
      @request = Request.find_by(id: params[:id]) || HolidayRequest.find_by(id: params[:id])
      if @request.nil?
        flash[:error] = "Request #{params[:id]} not found. Perhaps it has been deleted."
        redirect_to requests_path
        false
      end
    end

    def request_params
      permitted_keys = [:date, :shift, :fulfilling_swap_id]
      permitted_keys << :user_id if current_user.admin?
      params.require(:request).permit(*permitted_keys)
    end

    def check_owner
      unless current_user_can_edit?(@request)
        flash[:error] = "Only the request owner can do that."
        redirect_to @request
      end
    end

    def check_editable
      if @request.locked? && !current_user_can_edit?(@request)
        flash[:error] = @request.locked_reason
        redirect_to @request
      end
    end

    def holiday_request_url(*args)
      request_url(*args)
    end

end
