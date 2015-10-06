class RequestsController < ApplicationController
  before_action :require_confirmed_email
  before_action :find_request, except: [:new, :create, :index, :owned_index, :fulfilled, :pending]
  before_action :check_owner, except: [:new, :create, :show, :index, :owned_index, :fulfilled, :pending]
  before_action :check_editable, except: [:new, :create, :show, :index, :owned_index, :fulfilled, :pending]

  def new
    @request = Request.new(user: current_user)
  end

  def create
    @request = Request.new(request_params)
    @request.user ||= current_user
    if @request.save
      redirect_to @request
    else
      flash.now[:error] = "Request couldn't be created. Please check the errors and retry."
      @errors = @request.errors
      render 'new'
    end
  end

  def show
    case @request.state
    when 'seeking_offers'
      if @request.user == current_user
        # byebug
        @requests_to_swap_with = @request.offerable_swaps
        if @requests_to_swap_with.any?
          @availabilities_for_requests_to_swap_with = @request.user.availabilities_for(@requests_to_swap_with)
          render 'choose_swap'
# test this
        elsif @request.potential_matches.any?
          @suggested_availabilities = @request.user.availabilities_for(:potential_matches)
          render 'specify_availability'
        end
      else
        @requests_to_swap_with = current_user.offerable_swaps(@request)
        if @requests_to_swap_with.any?
          @availabilities_for_requests_to_swap_with = current_user.availabilities_for(@requests_to_swap_with)
        end
      end
# end test
    when 'received_offer', 'sent_offer', 'fulfilled'
      # Nothing extra to do
    else
      flash.now[:error] = "Request unexpectedly in #{@request.state} state"
    end
  end

  def old_create
    @request = Request.new(request_params)
    @request.user = current_user unless current_user.admin?

    raise
    if @request.fulfilling_swap_id # coming from 'choose_swap'
      if @request.update(state: :sent_offer)
        raise
        notify_swap_offer
        redirect_to @request
      else
        if @request.offerable_swaps.any?
          # raise
          flash.now[:error] = "Something went wrong! We couldn't make the offer. Probably someone got there before you."
          render 'choose_swap'
        else
          raise
          specify_availability
        end
      end
    elsif !@request.valid?
      specify_shift
    elsif @request.offerable_swaps.any? && !params[:cant_swap]
      render 'choose_swap'
    elsif (potential_matches = @request.potential_matches).any?
      specify_availability
    else
      raise
      if params[:from_step_1]
        flash[:notice] = "Skipped steps 2 and 3: no current matches and all availability is specified"
      end
      @request.save!
      flash[:success] = "Request created!"
      redirect_to @request
    end
  end

  def update
    # Should we handle failure to look up requests by id?
    # @request.assign_attributes(request_params)
    # raise
    if params[:request_to_swap_with_id]
      request_to_swap_with = Request.find_by(id: params[:request_to_swap_with_id])
      if request_to_swap_with && @request.send_swap_offer_to(request_to_swap_with)
        notify_swap_offered(from: @request, to: request_to_swap_with)
      # can we assume rollback after here?
      elsif request_to_swap_with.nil?
        flash[:error] = "Request to swap with could not be found; it may have just been deleted"
      elsif @request.fulfilling_swap != request_to_swap_with
        flash[:error] = "Your request already has a swap pending with #{@request.fulfilling_swap.user}'s #{@request.fulfilling_swap} request"
      elsif request_to_swap_with.fulfilling_user
        if request_to_swap_with.fulfilling_user != @request.user
          flash[:error] = "Sorry, we couldn't make the offer; #{@request.fulfilling_swap.fulfilling_user} beat you to it"
        else # Would it actually cause a save error if we beat ourselves to it?
          flash[:error] = "You, uh, beat yourself?"
        end
      else
        # What could cause this?
        flash[:error] = "Something went wrong! We couldn't make the offer. #{@request.errors.full_messages.join(". ")}"
      end
    elsif params[:offer_response]
      case params[:offer_response]
      when :accept
        if @request.accept_pending_swap
          notify_swap_accepted
        elsif @request.fulfilling_swap.nil?
          flash[:error] = "There was no pending swap offer to accept"
        else
          flash[:error] = "Something went wrong! We couldn't accept the swap. #{@request.errors.full_messages.join(". ")}"
        end
      when :decline
        request_we_declined_to_swap_for = @request.fulfilling_swap
        if @request.decline_pendind_swap
          notify_swap_declined(decliners_request: @request, offerers_request: request_we_declined_to_swap_for)
        elsif @request.fulfilling_swap.nil?
          flash[:error] = "There was no pending swap offer to decline"
        else
          flash[:error] = "Something went wrong! We couldn't decline the swap. #{@request.errors.full_messages.join(". ")}"
        end
      else
        flash[:error] = "Unexpected offer response: #{params[:offer_response]}"
      end

    # when ['received_offer', 'fulfilled']
    #   @request.save!
    #   notify_swap_accepted
    # when ['received_offer', 'seeking_offers']
    #   request_we_declined_to_swap_for = @request.fulfilling_swap
    #   @request.save!
    #   notify_swap_declined(from: request_we_declined_to_swap_for)
    # else
    #   if params[:cant_swap] # infer that user is not free for all @request.offerable_swaps
    #     @request.offerable_swaps.each do |request_user_cant_swap_for|
    #       # Is there any chance we couldn't update any of these availabilities because
    #       # the user made a different swap with one of them?
    #       @request.user.availability_for(request_user_cant_swap_for).update!(free: false)
    #     end
    #   else
    #     flash[:error] = "Unexpected state change from #{@request.previous_changes['state'].join(' to ')}"
    #   end
    end

    redirect_to @request
  end

  def offer_sub
    if @request.fulfill_by_sub(current_user)
      emails = [mailer.notify_sub(@request, current_user),
                mailer.remind_sub(@request, current_user)]
      emails.each &:deliver
      flash[:success] = "Thanks! We send #{@request.user} an email to let them know the good news."
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
    @requests = @owner.requests.on_or_after(Date.today)
  end

  def fulfilled
    @requests = Request.on_or_after(Date.today).fulfilled
    @today = @requests.where(date: Date.today)
    @this_week = @requests.where(date: (Date.today + 1)..(Date.today + 7))
    @later = @requests.where(date: (Date.today + 8)..(Date.today + 1000))
  end

  def pending
    @requests = Request.pending_requests(user_id)
    if @requests.count == 1
      redirect_to @requests.first
    end
  end

  def destroy
    @request.destroy
    flash[:success] = "Request deleted"
    redirect_to params[:redirect_to] || :back
  end

  private

    def user_id
      (current_user.admin? && params[:user_id]) || current_user.id
    end

    def notify_swap_offered
      mailer.notify_swap_offer(from: @request, to: @request.fulfilling_swap).deliver
      flash[:success] = "We sent #{@request.fulfilling_user} an email to let them know about your offer"
    end

    def notify_swap_accepted
      [mailer.notify_swap_accept(@request), mailer.remind_swap_accept(@request)].each &:deliver
      flash[:success] = "We sent #{@request.fulfilling_user} an email to let them know you accepted"
    end

    def notify_swap_declined(from: offer_request)
      mailer.notify_swap_decline(decliners_request: @request, offerers_request: offer_request).deliver
      flash[:success] = "We sent #{offer_request.user} an email to let them know you declined"
    end

    def find_request
      @request = Request.find(params[:id])
    end

    def request_params
      permitted_keys = [:date, :shift, :fulfilling_swap_id]
      permitted_keys << :user_id if current_user.admin?
      params.require(:request).permit(*permitted_keys)
    end

    def check_owner
      unless @request.user == current_user
        flash[:error] = "Only the request owner can do that."
        redirect_to @request
      end
    end

    def check_editable
      locked_reason = @request.locked?
      if @request.locked?
        flash[:error] = @request.locked_reason
        redirect_to @request
      end
    end
end
