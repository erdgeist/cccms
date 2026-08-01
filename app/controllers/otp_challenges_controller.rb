# The second half of a two-step login. A pending marker (set by
# sessions#create after a correct password) plus deadline and attempt
# counter live in the session; the real user_id is only written after a
# valid code, through a fresh session.
class OtpChallengesController < ApplicationController

  layout 'admin'

  MAX_ATTEMPTS = 5

  def new
    redirect_to login_path unless pending_user
  end

  def create
    user = pending_user
    return redirect_to login_path unless user

    session[:otp_attempts] = session[:otp_attempts].to_i + 1
    if session[:otp_attempts] > MAX_ATTEMPTS
      clear_pending
      flash[:error] = t("flash.otp.too_many_attempts")
      return redirect_to login_path
    end

    if user.verify_otp!(params[:code])
      return_to = session[:return_to]
      reset_session
      self.current_user = user
      session[:logged_in_at] = Time.now.to_i
      # an admin who logs in and goes straight to user management
      # is already elevated
      elevate! if user.is_admin?
      flash[:notice] = if user.is_admin?
        t("flash.elevation.granted_at_login",
          :minutes => AuthenticatedSystem::ELEVATION_MAX_AGE.in_minutes.to_i)
      else
        t("flash.common.logged_in")
      end
      redirect_to safe_return_to(return_to, :default => admin_path)
    else
      flash.now[:error] = t("flash.otp.code_mismatch")
      render :new
    end
  end

  private

    def pending_user
      return nil if session[:pending_otp_user_id].blank?
      if session[:otp_deadline].to_i < Time.now.to_i
        clear_pending
        return nil
      end
      @pending_user ||= User.find_by(:id => session[:pending_otp_user_id])
    end

    def clear_pending
      session.delete(:pending_otp_user_id)
      session.delete(:otp_deadline)
      session.delete(:otp_attempts)
    end
end
