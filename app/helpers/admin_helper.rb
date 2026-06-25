module AdminHelper

  def language_selector
    case I18n.locale
    when :de
      link_to raw('<span class="inactive">English</span>'), url_for(params.permit!.to_h.merge('locale' => 'en'))
    when :en
      link_to raw('<span class="inactive">Deutsch</span>'), url_for(params.permit!.to_h.merge('locale' => 'de'))
    end
  end
end
