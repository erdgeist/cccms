module ContentHelper

  def main_menu
    menu_items = MenuItem.order("position ASC").all
    render(
      :partial => 'content/main_navigation',
      :locals => {:menu_items => menu_items}
    )
  end

  def calendar
    occurrences = Occurrence.find_in_range(Time.now, (Time.now+6.weeks))

    if occurrences.empty?
      occurrences = Occurrence.find_next
    end

    occurrences = occurrences.reject { |o| o.node.nil? || o.node.head.nil? }

    render(
      :partial  => 'content/front_page_calendar',
      :locals   => {:occurrences => occurrences}
    )
  end

  def open_erfas_today
    occurrences = Occurrence
      .find_in_range(Time.now.beginning_of_day, Time.now.end_of_day)
      .joins(event: :tags)
      .where(tags: { name: 'open-day' })
      .reject { |o| o.node.nil? || o.node.head.nil? }
      .sample(3)

    return if occurrences.empty?

    render(
      :partial => 'content/open_erfas_today',
      :locals  => { :occurrences => occurrences }
    )
  end

  def weekday_abbr(time)
    RruleHumanizer.wday_abbr(time, I18n.locale)
  end

  def tags
    render :partial => 'content/tags'
  end

  def featured_articles
    @featured_articles = FeaturedArticle.all
    render :partial => 'content/featured_articles'
  end

  def headline_image
    @headline_asset = @page.headline_asset
    render :partial => 'content/headline_image' if @headline_asset || @page.assets.images.any? || @page.assets.pdfs.any?
  end

  # Returns the published_at attribute of a page if it is not nil, otherwise
  # it returns the auto-filled value of the created_at attribute
  def date_and_time_for_page page
    I18n.l(page.published_at, :format => :ccc) rescue I18n.l(page.created_at, :format => :ccc)
  end

  def date_for_page page
    I18n.l(page.published_at, :format => :ccc_date) rescue I18n.l(page.created_at, :format => :ccc_date)
  end

  def author_for_page page
    page.user ? page.user.login : "Unknown author"
  end

  def page_title
    if @page && @page.title && @page.title != ""
      "CCC | #{@page.title}"
    else
      "CCC | Chaos Computer Club"
    end
  end

  def humanized_asset_name asset
    asset.name.to_s.tr("_", " ")
  end

  # This method is an output filter for templates. It accepts any kind of text
  # and checks for an [aggregate short code within it. If such a code is found,
  # its # attributes are parsed and converted into parameters for the
  # render_collection method. The [aggregate ] short code will then be replaced
  # entirely with the output of the render_collection method.
  #
  # Syntax of the [aggregate ] short code:
  #
  # [aggregate
  #   children="all" | children="direct" # optional, at least one of children
  #   tags="update, pressemitteilung"    # or tags is required
  #   limit="20"
  #   order_by="published_at"
  #   order_direction="DESC"
  # ]


  def aggregate? content
    options = {}

    cccms_attributes = ActionView::Base.sanitized_allowed_attributes + ['lang']

    begin
      if content =~ /\[aggregate([^\]]*)\]/
        tag = $~.to_s
        matched_data = $1.scan(/\w+\="[a-zA-Z\s\/_\d,.=-]*"/)

        matched_data.each do |data|
          splitted_data = data.split("=", 2)
          options[splitted_data[0].to_sym] = splitted_data[1].gsub(/"/, "")
        end

        options[:partial] = select_partial(options[:partial])
        options[:node] = @page.node if options[:children].present?

        sanitize(content.sub(tag, render_collection(options)), :attributes => cccms_attributes)
      else
        sanitize(content, :attributes => cccms_attributes)
      end

    rescue
      Rails.logger.error("aggregate shortcode failed on page #{@page&.id}: #{e.class}: #{e.message}")
      fallback = content.sub(/\[aggregate[^\]]*\]/, "")
      fallback = sanitize(fallback, :attributes => cccms_attributes)
      fallback += content_tag(:p, t("content.aggregate_failed"), :class => "error_messages") if current_user
      fallback
    end
  end

  # Takes the parameters from the aggregate? method and renders the collection
  # from Page.aggregate(options) with a given partial
  def render_collection options
    @content_collection = Page.aggregate(options, params[:page])

    render(
      :partial => options[:partial],
      :collection => @content_collection,
      :as => :page
    )
  end

  private

  # Either return a custom partial path if it exsits or default to the standard
  # partial
  def select_partial partial
    if partial.to_s.match?(%r{\A[a-z0-9_]+(/[a-z0-9_]+)?\z}) && partial_exists?( partial )
      return "custom/partials/#{partial}"
    else
      return 'custom/partials/article'
    end
  end

  # Check if a custom partial exists in the proper location
  def partial_exists? partial
    File.exist?(
      Rails.root.join('app', 'views', 'custom', 'partials', "_#{partial}.html.erb")
    )
  end

  def asset_credit(asset)
    return nil unless asset
    return nil unless asset.has_credit?

    license = AssetLicense.find(asset.license_key)

    photo_label = t("asset_credits.photo", name: asset.name)
    photo = asset.source_url.present? ? link_to(photo_label, asset.source_url) : photo_label

    attribution_parts = [photo]
    attribution_parts << t("asset_credits.by", creator: asset.creator) if asset.creator.present?
    attribution = safe_join(attribution_parts, " ")

    license_text = if license
      name = t("asset_licenses.#{license.key}", default: license.key)
      phrase = license.style == "license" ? t("asset_credits.licensed_under", license: name) : name
      license.url.present? ? link_to(phrase, license.url) : phrase
    end

    full = license_text ? safe_join([attribution, license_text], ", ") : attribution
    safe_join([full, "."])
  end

  def glightbox_data(image, title)
    "title: #{title.to_s.tr(';', ',')};"
  end
end
