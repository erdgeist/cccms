class UsersController < ApplicationController
  include PinnedToDefaultLocale
  include RoleRequired

  # Private

  before_action :login_required
  before_action :find_user,     :only => [:show, :edit, :update, :reset_otp, :deactivate, :reactivate]
  before_action :require_admin, :only => [:index, :new, :create, :reset_otp, :deactivate, :reactivate]
  before_action :verify_status, :except => [:index]

  layout 'admin'

  ROLE_PRESETS = {
    "editor"    => [],
    "redaktion" => ["redaktion"],
    "admin"     => ["admin", "redaktion"]
  }.freeze

  GROUP_ORDER = [:admin, :redaktion, :editor, :alumni].freeze

  def index
    @users = User.order("login ASC").all.group_by(&:role_group)
  end

  def new
    @user = User.new(:roles => ROLE_PRESETS.fetch(params[:preset], []))
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

    if @user.update(permitted)
      flash[:notice] = t("flash.users.updated", :login => @user.login)
      redirect_to user_path(@user)
    else
      render :edit
    end
  end

  def show
  end

  def deactivate
    if @user == current_user
      flash[:error] = t("flash.users.cannot_deactivate_self")
    elsif @user.deactivate!(:actor => current_user)
      flash[:notice] = t("flash.users.deactivated", :login => @user.login)
    end

    redirect_to users_path
  end

  def reactivate
    if @user.reactivate!(:actor => current_user)
      flash[:notice] = t("flash.users.reactivated", :login => @user.login)
    end

    redirect_to users_path
  end

  def reset_otp
    @user.disable_otp!(:actor => current_user)
    flash[:notice] = t("flash.users.otp_reset", :login => @user.login)
    redirect_to edit_user_path(@user)
  end

  private

    def user_params
      permitted = params.fetch(:user, {})
                        .permit(:login, :email, :password, :password_confirmation,
                                :roles => [])
      # Checkbox arrays post a leading blank from the hidden field.
      permitted[:roles] = Array(permitted[:roles]).reject(&:blank?) if permitted.key?(:roles)
      permitted.delete(:roles) unless current_user.is_admin?
      permitted
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
      deny_role_access(:admin_required)
    end
end
