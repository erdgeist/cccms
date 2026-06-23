module AdminHelper
  
  def language_selector
    case I18n.locale
    when :de
      link_to raw('<span class="inactive">English</span>'), url_for(:overwrite_params => {:locale => :en})
    when :en
      link_to raw('<span class="inactive">Deutsch</span>'), url_for(:overwrite_params => {:locale => :de})
    end
  end
end
