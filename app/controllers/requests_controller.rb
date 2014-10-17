class RequestsController < ApplicationController
  before_action :require_signin
  before_action :require_admin, except: []

  def new
    @request = Request.new
  end

  def create
    # @user = User.new(user_params)
    # if @user.save
    #   # sign_in @user # If we want to sign in upon sign-up
    #   flash[:success] = "Welcome, #{@user.name}"
    #   redirect_to @user
    # else
    #   render 'new' # Try again
    # end
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
    # @users = User.all
  end

  def show
    # @user = User.find(params[:id])
  end

  private

    # def user_params
    #   params.require(:user).permit(:name, :email, :password,
    #                  :password_confirmation)
    # end
end
