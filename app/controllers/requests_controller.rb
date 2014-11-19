class RequestsController < ApplicationController
  before_action :require_signin
  before_action :check_editable, only: [:edit, :update]

  def new
    @request = Request.new
  end

  def create
    @request = Request.new(request_params)
    @request.user = current_user
    if @request.save
      flash[:success] = "Request created"
      redirect_to requests_path
    else
      @errors = @request.errors
      render 'new' # Try again
    end
  end

  def edit
  end

  def update
    Request.transaction do
      Availability.transaction do
        if @request.update_attributes(request_params)
          if @request.fulfilled?
        
            flash[:success] = "Marked request fulfilled."
            # Remove availability for swapped_shift
            @request.user.availabilities.where(start: @request.swapped_shift).each do |a|
              a.destroy
              flash[:success] += " Destroyed my #{a.time_string} availability."
            end

            # Remove fulfilling_user's availability for this shift if it exists
            @request.fulfilling_user.availabilities.where(start: @request.start).each do |a|
              a.destroy
              flash[:success] += " Destroyed #{a.user.name}'s #{a.time_string} availability."
            end
        
            # Fulfill request for swapped_shift if it exists
            @request.fulfilling_user.requests.where(start: @request.swapped_shift).each do |r|
              r.update_attributes(fulfilled: true, fulfilling_user: @request.user,
                                  swapped_shift: @request.start)
              flash[:success] += " Marked #{r.user.name}'s #{r.time_string} request fulfilled"
            end
        
            # Email the other user, and crisis line staff
          else
            flash[:success] = "Update successful"
          end
          redirect_to @request
        else
          render 'edit' # Try again
        end
      end
    end
  end

  # post '/requests/:id/offer/sub', to: 'requests#offer_sub', as: :offer_sub
  def offer_sub
    Request.transaction do
      Availability.transaction do
    
        @request = Request.find(params[:id])
        if @request.fulfilling_user.nil?
          associate_fulfilling_user
          @request.fulfilled = true
          @request.swapped_shift = nil # just to be sure
          if @request.save
            UserMailer.notify_sub(@request).deliver
            flash[:success] = "OK, we let #{@request.user.name} know the good news."
          else
            flash[:errors] = "Something went wrong."
          end
        else
          flash[:errors] = "Sorry, #{@request.fulfilling_user.name} beat you to it."
        end
      end
    end

    redirect_to @request
  end

  # post '/requests/:id/offer/swap', to: 'requests#offer_swap', as: :offer_swap
  def offer_swap
    Request.transaction do
      Availability.transaction do
    
        @request = Request.find(params[:id])
        if @request.fulfilling_user.nil?
          @availability = @request.user.availabilities.find(params[:request][:availability_id])
          if @availability.nil? || @availability.request
            flash[:errors] = "Sorry, #{@request.user.name} isn't available to swap then."
          else
            associate_fulfilling_user
            @request.swapped_shift = @availability.start
            # Attach the fulfilling user's availability if it exists
            if @request.save
              UserMailer.notify_swap_offer(@request, @availability).deliver
              flash[:success] = "OK, we sent #{@request.user.name} an email to let them know about your offer."
            else
              flash[:errors] = "Something went wrong."
            end
          end
        else
          flash[:errors] = "Sorry, #{@request.fulfilling_user.name} beat you to it"
        end
      end
    end
    
    redirect_to @request
  end

  def accept_swap
    @request = Request.find(params[:id])
    Request.transaction do
      Availability.transaction do

        @request.fulfilled = true
        flash[:success] = "Marked request fulfilled."
        # Remove availability for swapped_shift
        @request.user.availabilities.where(start: @request.swapped_shift).each do |a|
          a.destroy
          flash[:success] += " Destroyed my #{a.time_string} availability."
        end

        # Remove fulfilling_user's availability for this shift if it exists
        @request.fulfilling_user.availabilities.where(start: @request.start).each do |a|
          a.destroy
          flash[:success] += " Destroyed #{a.user.name}'s #{a.time_string} availability."
        end
    
        # Fulfill request for swapped_shift if it exists
        @request.fulfilling_user.requests.where(start: @request.swapped_shift).each do |r|
          r.update_attributes(fulfilled: true, fulfilling_user: @request.user,
                              swapped_shift: @request.start)
          flash[:success] += " Marked #{r.user.name}'s #{r.time_string} request fulfilled"
        end
    
        if @request.save
          # XXX email crisis line staff, too
          UserMailer.notify_swap_accept(@request).deliver
        else
          flash[:error] = "Something went wrong; swap not accepted."
        end
      end
    end
    redirect_to @request
  end

  def decline_swap
    @request = Request.find(params[:id])
    Request.transaction do
      Availability.transaction do
        # disassociate offerer's availability
        @request.fulfilling_user.availabilities.where(start: @request.start).each do |a|
          a.request = nil
          a.save!
        end
        @request.swapped_shift = nil
        declinee = @request.fulfilling_user
        @request.fulfilling_user = nil
        if @request.save
          UserMailer.notify_swap_decline(@request, declinee).deliver
          flash[:success] = "The offer has been declined and the offerer notified."
        end
      end
    end
    redirect_to @request
  end

  def index
    if params[:past]
      if current_user.admin?
        @requests = Request.order(:start)
      else
        redirect_to requests_path
      end
    elsif params[:owner]
      if current_user.admin? || params[:owner].to_i == current_user.id
        @requests = User.find(params[:owner]).requests.order(:start)
      else
        redirect_to requests_path(owner: current_user)
      end
    else
      @requests = Request.where(fulfilled: false).where("start > ?", DateTime.now).order(:start)
    end
  end

  def show
    @request = Request.find(params[:id])
    @swap_candidates = @request.swap_candidates
  end

  def destroy
    req = Request.find(params[:id])
    if current_user_can_edit?(req)
      req.destroy
      flash[:success] = "Request deleted"
    else
      flash[:error] = "You don't have permission to delete that"
    end
    redirect_to :back
  end

  private

    def associate_fulfilling_user
      @request.fulfilling_user = User.find(params[:request][:fulfilling_user_id])
      availability = @request.fulfilling_user.availabilities.find_by(start: @request.start)
      # Create availability if it doesn't exist?
      if availability
        availability.request = @request
        availability.save!
      end
    end

    def check_editable
      @request = Request.find(params[:id])
      reason = if @request.fulfilled?
          "The request can't be changed after it's been fulfilled."
        elsif @request.pending_offer?
          "The request can't be changed while there is a pending offer."
        end
      redirect_to @request, notice: reason if reason
    end

    def request_params
      params.require(:request).permit(:start, :shift, :text, :fulfilled,
                                      :fulfilling_user_id, :swapped_shift)
    end
end
