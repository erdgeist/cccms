class UsersController < ApplicationController

  # Private

  before_action :login_required
  before_action :find_user,     :only => [:show, :edit, :update, :destroy, :reset_otp]
  before_action :verify_status, :except => [:index, :show]

  layout 'admin'

  def index
    @users = User.order("login ASC").all.group_by do |user|
      user.admin? ? :admin : :user
    end
  end

  def new
    @user = User.new(admin: params[:admin].present?)
  end

  def create
    @user = User.new user_params

    if @user.save
      flash[:notice] = t("flash.users.created", :login => @user.login)
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
      flash[:notice] = t("flash.users.updated", :login => @user.login)
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

  def reset_otp
    return deny_user_access unless current_user.admin?
    @user.disable_otp!(:actor => current_user)
    flash[:notice] = t("flash.users.otp_reset", :login => @user.login)
    redirect_to edit_user_path(@user)
  end

  private

    def user_params
      allowed = [:login, :email, :password, :password_confirmation]
      allowed << :admin if current_user.admin?
      params.fetch(:user, {}).permit(allowed)
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
      flash[:notice] = t("flash.common.admin_required")
      redirect_to users_path
    end
end
