class RequestsController < ApplicationController
  before_action :require_signin

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
    @request = Request.find(params[:id])
  end

  def update
    @request = Request.find(params[:id])
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
          # attach availability if it exists
          if @request.save
            flash[:success] = "OK, we'll let #{@request.user.name} know."
          else
            flash[:errors] = "Something went wrong"
          end
        else
          flash[:errors] = "Sorry, #{@request.fulfilling_user.name} beat you to it"
        end
        # Email the request owner
  
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
            @request.swapped_shift = @availability.start if @availability
            # Attach the fulfilling user's availability if it exists
            if @request.save
              flash[:success] = "OK, we'll let #{@request.user.name} know."
            else
              flash[:errors] = "Something went wrong"
            end
          end
        else
          flash[:errors] = "Sorry, #{@request.fulfilling_user.name} beat you to it"
        end
        # Email the request owner

      end
    end
    
    redirect_to @request
  end

  # '/requests/:id/sub/:by'
  # '/requests/:id/swap/:availability_id/:with'
  def fulfill
    @request = Request.find(params[:id])
    @request.fulfilled = true
    if params[:by]
      @sub = true
      @request.fulfilling_user = User.find(params[:by])
    else
      @swap = true
      @availability = Availability.find(params[:availability_id])
      @request.swapped_shift = @availability.start
      @request.fulfilling_user = User.find(params[:with])
    end
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
        availability.save
      end
    end

    def request_params
      params.require(:request).permit(:start, :shift, :text, :fulfilled,
                                      :fulfilling_user_id, :swapped_shift)
    end
end
