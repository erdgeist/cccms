# Self-service TOTP enrollment, deliberately scoped to current_user only:
# an administrator must never hold another account's secret -- admins get
# the witnessed reset on the user page instead.
class OtpEnrollmentsController < ApplicationController
  before_action :login_required

  layout 'admin'

  # QR plus confirmation form; only meaningful while a pending secret exists.
  def show
    redirect_to edit_user_path(current_user) if current_user.otp_pending_secret.blank?
  end

  # Begins (or restarts) enrollment. Requires the current password so an
  # unattended logged-in session cannot be enrolled onto a stranger's phone.
  def create
    unless User.authenticate(current_user.login, params[:current_password].to_s)
      flash[:error] = t("flash.otp.wrong_password")
      return redirect_to edit_user_path(current_user)
    end
    current_user.begin_otp_enrollment!
    redirect_to otp_enrollment_path
  end

  # Confirms with the first generated code.
  def update
    if current_user.confirm_otp_enrollment!(params[:code])
      flash[:notice] = t("flash.otp.enabled")
      redirect_to edit_user_path(current_user)
    else
      flash.now[:error] = t("flash.otp.code_mismatch_rescan")
      render :show
    end
  end

  # Self-service disable: password AND a current code.
  def destroy
    unless User.authenticate(current_user.login, params[:current_password].to_s) &&
           current_user.verify_otp!(params[:code])
      flash[:error] = t("flash.otp.wrong_credentials")
      return redirect_to edit_user_path(current_user)
    end
    current_user.disable_otp!(:actor => current_user)
    flash[:notice] = t("flash.otp.disabled")
    redirect_to edit_user_path(current_user)
  end
end
