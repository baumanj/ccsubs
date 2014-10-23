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
    if @request.update_attributes(request_params)
      flash[:success] = "Update successful"
      redirect_to requests_path
    else
      render 'edit' # Try again
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

    def request_params
      params.require(:request).permit(:start, :shift, :text, :fulfilled)
    end
end
