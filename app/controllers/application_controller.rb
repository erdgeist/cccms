class ApplicationController < ActionController::Base
  include AuthenticatedSystem

  protect_from_forgery

  before_action :set_locale
  before_action :enforce_otp_enrollment

  helper_method :safe_return_to

  protected

  def set_locale
    if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym)
      I18n.locale = params[:locale].to_sym
    else
      I18n.locale = I18n.default_locale
    end
  end

  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end

  def safe_return_to(url, default: events_path)
    return default if url.blank?
    uri = URI.parse(url)
    return default if uri.host.present?
    return default unless url.start_with?('/')
    url
  rescue URI::InvalidURIError
    default
  end

  # The hard gate for the slow transition: a user flagged otp_required
  # who has not enrolled can reach only enrollment, their own user page,
  # the login machinery, and the challenge -- everything else funnels
  # into setup. Anonymous visitors are untouched (not logged_in?).
  def enforce_otp_enrollment
    return unless logged_in?
    return unless current_user.otp_required? && !current_user.otp_enrolled?
    return if %w[otp_enrollments otp_challenges sessions users].include?(controller_name)
    flash[:error] = "Your account requires a second factor -- set it up to continue."
    redirect_to edit_user_path(current_user)
  end
end
