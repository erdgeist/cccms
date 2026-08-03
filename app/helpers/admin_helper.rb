module AdminHelper
  def language_selector
    case I18n.locale
    when :de
      link_to raw('<span class="inactive">English</span>'), url_for(params.permit(:locale, :page_path).to_h.merge('locale' => 'en'))
    when :en
      link_to raw('<span class="inactive">Deutsch</span>'), url_for(params.permit(:locale, :page_path).to_h.merge('locale' => 'de'))
    end
  end

  def flag(icon_name, hint, tier: nil)
    classes = ["flag", tier && "flag_#{tier}"].compact.join(" ")
    content_tag(:span, icon(icon_name, library: "tabler", "aria-hidden": true),
                :role => "img", :class => classes,
                :title => hint, "aria-label" => hint)
  end
end
