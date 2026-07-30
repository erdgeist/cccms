module SocialHelper
  # The club's name is a proper noun and identical in both locales.
  OG_SITE_NAME = "Chaos Computer Club".freeze

  # Facebook's og:locale wants a language_TERRITORY tag, not a bare
  # language code. Anything not listed falls back to the default locale's
  # tag rather than emitting something no consumer recognises.
  OG_LOCALES = { :de => "de_DE", :en => "en_GB" }.freeze

  OG_DEFAULT_IMAGE = "/images/social_default.png".freeze

  # Previews render unpublished drafts behind nothing but a token in the
  # URL, so these controllers emit no social metadata at all.
  PREVIEW_CONTROLLERS = %w[shared_previews pages].freeze

  # Search result pages are the classic noindex case. Previews join them
  # for the reason above.
  NOINDEX_CONTROLLERS = (PREVIEW_CONTROLLERS + %w[search]).freeze

  # og:image must be an absolute URL with a scheme; a path is ignored.
  # request.base_url rather than a routing helper, so default_url_options
  # cannot inject a locale prefix into a static asset path.
  def og_absolute_url(path)
    "#{request.base_url}#{path}"
  end

  def social_meta?
    !PREVIEW_CONTROLLERS.include?(controller_name)
  end

  def robots_directive
    return nil unless NOINDEX_CONTROLLERS.include?(controller_name)

    # nofollow on previews as well, so a crawler that reaches one does not
    # walk out of it into whatever the draft links to. Search pages omit it,
    # since following result links is the one useful thing a crawler can do
    # there.
    PREVIEW_CONTROLLERS.include?(controller_name) ? "noindex, nofollow" : "noindex"
  end

  # The headline asset's card if it has one, else the site default.
  # has_variant?
  #
  # The query suffix defeats indefinite crawler caching: FileAttachment
  # deliberately keeps public URLs stable across a file replacement, so
  # without it Facebook would serve the superseded card forever.
  def og_image_url
    asset = @page&.persisted? ? @page.headline_asset : nil

    if asset&.has_variant?(:og)
      og_absolute_url("#{asset.upload.url(:og)}?v=#{asset.upload_updated_at.to_i}")
    else
      og_absolute_url(OG_DEFAULT_IMAGE)
    end
  end

  # Both files are exactly 1200x630, so these are constants either way.
  def og_image_width
    FileAttachment::OG_WIDTH
  end

  def og_image_height
    FileAttachment::OG_HEIGHT
  end

  def og_image_alt
    asset = @page&.persisted? ? @page.headline_asset : nil
    asset&.has_variant?(:og) ? humanized_asset_name(asset) : OG_SITE_NAME
  end

  def og_title
    @page&.title.presence || OG_SITE_NAME
  end

  # Public controllers are deliberately not pinned to the default locale,
  # so Globalize follows I18n.locale here and the abstract arrives in the
  # language being served. Abstracts hold markup, hence strip_tags.
  def og_description
    text = strip_tags(@page&.abstract.to_s).squish
    return truncate(text, :length => 200, :separator => " ") if text.present?

    t("layouts.social_meta.site_description")
  end

  # A rendered page is a piece of content; the aggregate views (search,
  # tags, gallery) have no @page and are the site itself.
  def og_type
    @page&.persisted? ? "article" : "website"
  end

  def og_published_time
    @page&.published_at&.iso8601
  end

  # The address of the version actually being served, not of the URL that
  # was requested. So /de/updates/foo points at /updates/foo, and a page
  # with no English translation requested under /en/ points at the German
  # URL rather than claiming to be an English page. The query string is
  # dropped, which is what makes it canonical.
  def og_canonical_url
    locale = @page&.persisted? ? og_locale_key : I18n.locale
    og_locale_url(locale)
  end

  def og_locale
    OG_LOCALES.fetch((@page&.effective_lang || I18n.locale).to_sym,
                     OG_LOCALES[I18n.default_locale.to_sym])
  end

  # Locales that can appear in a URL. Cccms::LOCALES will replace this when
  # the set_locale allowlist lands; :root is in available_locales but is not
  # a language.
  def og_url_locales
    I18n.available_locales - [:root]
  end

  # The request path with any locale prefix stripped, so a locale-specific
  # URL can be rebuilt from it. /en/updates/foo, /de/updates/foo and
  # /updates/foo all reduce to /updates/foo.
  def og_bare_path
    pattern = og_url_locales.join("|")
    request.path.sub(%r{\A/(?:#{pattern})(?=/|\z)}, "").presence || "/"
  end

  # Absolute URL for this page in one locale. The default locale is
  # unprefixed, matching default_url_options, so /updates/foo is the
  # canonical German address and /de/updates/foo is a duplicate of it.
  def og_locale_url(locale)
    locale = locale.to_sym
    locale = I18n.default_locale unless og_url_locales.include?(locale)

    path = og_bare_path
    return og_absolute_url(path) if locale == I18n.default_locale

    og_absolute_url(path == "/" ? "/#{locale}" : "/#{locale}#{path}")
  end

  # One entry per locale in which the page genuinely has a translation,
  # including a self-reference, which Google requires. A locale with no
  # translation is omitted: /en/ would render German content through the
  # fallback chain, which is not an English version of the page. With only
  # one translation there is nothing to declare.
  def og_hreflang_alternates
    return [] unless @page&.persisted?

    locales = @page.translated_locales.map(&:to_sym) & og_url_locales
    return [] if locales.size < 2

    locales.sort.map { |locale| [locale.to_s, og_locale_url(locale)] }
  end

  # Only locales in which this page genuinely has a translation, so a
  # crawler is not told about a variant that would fall back.
  def og_locale_alternates
    return [] unless @page

    (@page.translated_locales.map(&:to_sym) - [og_locale_key]).filter_map do |locale|
      OG_LOCALES[locale]
    end
  end

  private

    def og_locale_key
      (@page&.effective_lang || I18n.locale).to_sym
    end
end
