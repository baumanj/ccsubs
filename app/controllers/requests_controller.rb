class RequestsController < ApplicationController
  before_action :require_signin
  before_action :require_confirmed_email
  before_action :find_request, except: [:new, :create, :index, :owned_index, :fulfilled, :pending]
  before_action :check_owner, only: [:update, :delete, :accept_swap, :decline_swap]
  before_action :check_editable, only: [:update, :destroy]
  before_action :check_request_is_open, only: [:offer_sub, :offer_swap]

  def new
    @user = current_user
    @request = Request.new(params.permit(:date, :shift, :text))
    @suggested_availabilities = current_user.suggested_availabilities(include_known: false)
  end

  # post '/requests/:id/offer/sub', to: 'requests#offer_sub', as: :offer_sub
  def offer_sub
    emails = [mailer.notify_sub(@request, current_user),
              mailer.remind_sub(@request, current_user)]
    if @request.fulfill_by_sub(current_user)
      emails.each &:deliver
      flash[:success] = "OK, we let #{@request.user} know the good news."
    else
      flash[:error] = @request.errors.full_messages.join(". ")
    end

    redirect_to @request
  end

  # post '/requests/:id/offer/swap', to: 'requests#offer_swap', as: :offer_swap
  def offer_swap
    offer_request = Request.find(params[:offer_request_id])
    email = mailer.notify_swap_offer(@request, offer_request)
    if @request.set_pending_swap(offer_request)
      email.deliver
      flash[:success] = "OK, we sent #{@request.user} an email to let them know about your offer."
    else
      flash[:error] = @request.errors.full_messages.join(" ")
    end
      
    redirect_to :back
  end

  def decline_swap
    offer_request = @request.fulfilling_swap
    email = mailer.notify_swap_decline(@request, offer_request)
    if @request.decline_pending_swap
      email.deliver
      flash[:success] = "#{offer_request.user}'s offer has been declined."
    else
      flash[:error] = @request.errors.full_messages.join(" ")
    end
    redirect_to @request
  end

  def accept_swap
    emails = [mailer.notify_swap_accept(@request),
              mailer.remind_swap_accept(@request)]
    if @request.accept_pending_swap
      emails.each &:deliver
      flash[:success] = "#{@request.fulfilling_swap.user}'s offer has been accepted!"
    else
      flash[:error] = @request.errors.full_messages.join(" ")
    end
    redirect_to @request
  end

  def index
    if params[:past]
      if current_user.admin?
        @requests = Request.order(:date, :shift)
      else
        redirect_to requests_path
      end
    else
      @requests = Request.all_seeking_offers
    end
  end

  def owned_index
    user_id = params[:user_id] || current_user.id
    if current_user.admin? || user_id.to_i == current_user.id
      @owner = User.find(user_id)
      @requests = @owner.requests.on_or_after(Date.today)
    else
      redirect_to requests_path(owner: current_user)
    end
  end

  def fulfilled
    @requests = Request.on_or_after(Date.today).fulfilled
    @today = @requests.where(date: Date.today)
    @this_week = @requests.where(date: (Date.today + 1)..(Date.today + 7))
    @later = @requests.where(date: (Date.today + 8)..(Date.today + 1000))
  end

  def pending
    @requests = Request.pending_requests(params[:user_id])
    if @requests.count == 1
      redirect_to @requests.first
    end
  end

  def show
    @swap_candidates = if current_user == @request.user
      @request.swap_candidates
    else
      @request.swap_candidates(current_user)
    end
    @conflict = current_user.conflict_for(@request)
  end

  def destroy
    @request.destroy
    flash[:success] = "Request deleted"
    redirect_to params[:redirect_to] || :back
  end

  private

    def find_request
      @request = Request.find(params[:id])
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
    
    def check_request_is_open
      unless @request.open?
        redirect_to :back, flash: { warning: "Sorry, this request is no longer open." }
      end
    end
end
