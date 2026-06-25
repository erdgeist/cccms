class UsersController < ApplicationController

  # Private

  before_action :login_required
  before_action :find_user,     :only => [:show, :edit, :update, :destroy]
  before_action :verify_status, :except => [:index, :show]

  layout 'admin'

  def index
    @users = User.order("login ASC").all.group_by do |user|
      user.admin? ? :admin : :user
    end
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new user_params

    if @user.save
      flash[:notice] = "User created #{@user.login}"
      redirect_to user_path(@user)
    else
      render :new
    end
  end

  def edit
  end

  def update
    permitted = user_params
    permitted.delete(:admin) unless current_user.is_admin?
            
    if @user.update(permitted)
      flash[:notice] = "Updated user #{@user.login}"
      redirect_to user_path(@user)
    else
      render :edit
    end
  end

  def show
  end

  def destroy
    @user.destroy if @user
    redirect_to users_path
  end

  private

    def user_params
      params.fetch(:user, {}).permit(:login, :email, :password, :password_confirmation, :admin)
    end

    def find_user
      @user = User.find(params[:id])
    end

    def verify_status
      @user ||= User.new
      unless @user.id == current_user.id || current_user.admin
        deny_user_access
      end
    end

    def deny_user_access
      flash[:notice] = "Sorry, you need to be an admin for this action"
      redirect_to users_path
    end
end
