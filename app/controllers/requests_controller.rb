class RequestsController < ApplicationController
  before_action :require_signin
  before_action :require_admin, except: []

  def new
    @request = Request.new
  end

  def create
    @request = Request.new(request_params)
    @request.start = DateTime.parse(params[:request][:start])
    @request.user = current_user
    if @request.save
      flash[:success] = "Request created"
      redirect_to @request
    else
      @errors = @request.errors
      render 'new' # Try again
    end
  end

  def edit
    # @user = User.find(params[:id])
  end

  def update
    # @user = User.find(params[:id])
    # if params[:user][:password].empty? &&  params[:user][:password_confirmation].empty?
    #   params[:user].delete(:password)
    #   params[:user].delete(:password_confirmation)
    # end
    # if @user.update_attributes(user_params)
    #   flash[:success] = "Update successful"
    #   redirect_to @user
    # else
    #   render 'edit' # Try again
    # end
  end

  def index
    @requests = Request.where("start > ?", DateTime.now)
  end

  def show
    @request = Request.find(params[:id])
  end

  private

    def request_params
      params.require(:request).permit(:start, :text)
    end
end
