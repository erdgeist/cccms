class ApplicationController < ActionController::Base
  include AuthenticatedSystem

  protect_from_forgery

  before_action :set_locale

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
end
