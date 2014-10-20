class RequestsController < ApplicationController
  before_action :require_signin
  before_action :require_admin, except: []

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
    @requests = Request.where("start > ?", DateTime.now)
  end

  def show
    @request = Request.find(params[:id])
  end

  private

    def request_params
      params.require(:request).permit(:start, :shift, :text)
    end
end
