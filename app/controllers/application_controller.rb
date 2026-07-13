class ApplicationController < ActionController::Base
  include AuthenticatedSystem

  protect_from_forgery

  before_action :set_locale

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
end
