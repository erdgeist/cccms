# Step-up authentication for janitorial work. Mirrors the two-step login's
# attempt cap: verify_otp! guards replay but not rate, and an attacker with a
# stolen cookie would otherwise have unlimited tries at a six-digit code.
class ElevationsController < ApplicationController
  include RoleRequired

  layout 'admin'

  before_action :login_required
  before_action :require_admin

  MAX_ATTEMPTS = 5

  def new
    redirect_to admin_path if elevated?
  end

  def create
    return render(:new) unless current_user.otp_enrolled?

    session[:elevation_attempts] = session[:elevation_attempts].to_i + 1
    if session[:elevation_attempts] > MAX_ATTEMPTS
      logout_killing_session!
      flash[:error] = t("flash.otp.too_many_attempts")
      return redirect_to(login_path)
    end

    if current_user.verify_otp!(params[:code])
      session.delete(:elevation_attempts)
      elevate!
      redirect_to safe_return_to(session.delete(:elevation_return_to),
                                 :default => users_path)
    else
      flash.now[:error] = t("flash.otp.code_mismatch")
      render :new
    end
  end

  def destroy
    drop_elevation!
    flash[:notice] = t("flash.elevation.dropped")
    redirect_to admin_path
  end
end
