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

  def admin_bridge
    {
      :urls => {
        :search           => admin_search_path,
        :menu_search      => admin_menu_search_path,
        :dashboard_search => admin_dashboard_search_path,
        :parameterize_preview => parameterize_preview_nodes_path
      },
      :strings => {
        :lock_lost_prefix => t("layouts.admin.lock_lost_prefix"),
        :lock_lost_link   => t("layouts.admin.lock_lost_link"),
        :insert_image     => t("layouts.admin.insert_image"),
        :insert_image_tooltip => t("layouts.admin.insert_image_tooltip"),
        :copied           => t("layouts.admin.copied"),
        :needs_redaktion  => t("layouts.admin.needs_redaktion"),
        :import_markdown  => t("layouts.admin.import_markdown"),
        :import_markdown_tooltip => t("layouts.admin.import_markdown_tooltip"),
        :import_markdown_placeholder => t("layouts.admin.import_markdown_placeholder"),
        :cancel           => t("admin.common.cancel"),
        :insert           => t("layouts.admin.insert")
      }
    }.to_json
  end

  def redirect_flag_hint page
    target = page.redirect_target
    return t("nodes.show.redirect_flag_broken") unless target

    target.internal? ? t("nodes.show.redirect_flag", :path => target.node.unique_name)
                     : t("nodes.show.redirect_flag_url", :url => target.url)
  end
end
