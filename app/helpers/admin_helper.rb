module AdminHelper
  
  def language_selector
    case I18n.locale
    when :de
      link_to 'English (Aktiv: Deutsch)', url_for(:overwrite_params => {:locale => :en})
    when :en
      link_to 'Deutsch (Active: English)', url_for(:overwrite_params => {:locale => :de})
    end
  end
end
