require 'xml'

class Page < ApplicationRecord

  PUBLIC_TEMPLATE_PATH = File.join(%w(custom page_templates public))
  FULL_PUBLIC_TEMPLATE_PATH = Rails.root.join('app', 'views', PUBLIC_TEMPLATE_PATH)

  # Mixins and Plugins
  acts_as_taggable
  acts_as_list :column => :revision, :scope => :node_id

  translates :title, :abstract, :body # Globalize2

  # Template names render as filesystem paths; only names actually
  # present in the public template directory are acceptable. Validated
  # only on change so legacy rows whose template file has since
  # vanished stay saveable -- valid_template already falls back to
  # standard_template for those at render time.
  validates :template_name,
            :inclusion => { :in => ->(_) { Page.custom_templates } },
            :allow_nil => true,
            :if        => :template_name_changed?

  # Associations
  belongs_to :node, optional: true
  belongs_to :user, optional: true
  belongs_to :editor, :class_name => "User", optional: true
  has_many   :related_assets
  has_many   :assets, -> { order("position ASC") }, :through => :related_assets

  # Named scopes
  scope :drafts, -> { joins(:node).includes(:translations).where("nodes.draft_id = pages.id") }
  scope :heads,  -> { joins(:node).includes(:translations).where("nodes.head_id = pages.id") }

  # Filter
  before_create :set_page_title
  before_create :set_template
  before_save   :rewrite_links_in_body

  # Class Methods

  # This method is most likely called from the ContentHelper.render_collection
  # method which aggregates pages into a collection, based on parameters it
  # recieves. This method then calls Page.aggregate with these parameters.
  # The Page.aggregate method comes with a defaults hash. These options are
  # partially or entirely overwritten by the options hash. Afterwards the merged
  # parameters are used to query the DB for Pages matching these parameters.
  # The aggregation only takes published pages into account.

  def self.aggregate options, page=1
    defaults = {
      :tags             => "",
      :limit            => 25,
      :order_by         => "pages.id",
      :order_direction  => "ASC"
    }

    options = defaults.merge options

    scope = Page.heads
    unless options[:tags].blank?
      tag_names = options[:tags].gsub(/\s/, ",").split(",").map(&:strip).map(&:downcase).uniq.reject(&:blank?)

      unless tag_names.empty?
        scope = scope
          .joins("JOIN taggings ON taggings.taggable_id = pages.id
                  AND taggings.taggable_type = 'Page'
                  AND taggings.context = 'tags'")
          .joins("JOIN tags ON tags.id = taggings.tag_id")
          .where("LOWER(tags.name) IN (?)", tag_names)
          .group("pages.id")
          .having("COUNT(DISTINCT tags.id) = ?", tag_names.length)
      end
    end

    if options[:node] && options[:children] == "direct"
      scope = scope.where(nodes: { parent_id: options[:node].id })
    elsif options[:node] && options[:children] == "all"
      scope = scope.where(nodes: { id: options[:node].descendants.pluck(:id) })
    end

    direction = %w[ASC DESC].include?(options[:order_direction]&.upcase) ? options[:order_direction].upcase : "ASC"

    if options[:order_by] == "title"
      return scope
        .order(Arel.sql("(SELECT pt.title FROM page_translations pt WHERE pt.page_id = pages.id AND pt.locale = #{ActiveRecord::Base.connection.quote(I18n.locale.to_s)}) #{direction}"))
        .paginate(:page => page, :per_page => options[:limit])
    end

    column = options[:order_by].to_s.sub(/\Apages\./, "")
    column = "id" unless %w[id published_at created_at updated_at].include?(column)

    scope.order("pages.#{column} #{direction}")
      .paginate(:page => page, :per_page => options[:limit])
  end

  def self.custom_templates
    files = Dir.entries(FULL_PUBLIC_TEMPLATE_PATH).select do |x|
      x if x.gsub!(".html.erb", "")
    end
  end

  def self.non_default_locales
    I18n.available_locales - [:root, I18n.default_locale]
  end

  # One row per non-default locale, read from the actual translation
  # row -- never through the locale-dependent accessor, so a locale
  # with no real translation yet reports as absent rather than quietly
  # showing a fallback value borrowed from another locale.
  def translation_summary
    Page.non_default_locales.map do |locale|
      translation = translations.find_by(:locale => locale)
      {
        :locale     => locale,
        :exists     => translation.present?,
        :title      => translation&.title,
        :updated_at => translation&.updated_at,
        :outdated   => translation.present? && outdated_translations?(:locale => locale)
      }
    end
  end

  def self.untranslated(options = {:locale => :de})
    PageTranslation.all.group_by(&:page_id).select do |k,v|
      v.size == 1 && v.map{|x| x.locale}.include?(options[:locale])
    end
  end

  # Returns only those pages that have outdated translations. See
  # outdated_translations? for more information.
  # Takes :locale => <locale> and :delta_time => 12.hours as options
  def self.find_with_outdated_translations options = {}
    Page.includes(:translations).select do |page|
      page.outdated_translations? options
    end
  end

  # Is used to compare a node's head with the node's draft

  def has_changes_to? draft
    return true unless node == draft.node
    return true unless assets == draft.assets
    return true unless tag_list == draft.tag_list
    return true unless template_name == draft.template_name
    return true unless translated_locales.sort_by(&:to_s) == draft.translated_locales.sort_by(&:to_s)
    changed = false
    translated_locales.each { |locale| I18n.with_locale(locale) { changed = true unless title == draft.title && abstract == draft.abstract && body == draft.body } }
    return changed
  end

  # Instance Methods

  def public_template_path
    File.join(PUBLIC_TEMPLATE_PATH, template_name)
  end

  def full_public_template_path
    File.join(FULL_PUBLIC_TEMPLATE_PATH, template_name)
  end

  def template_exists?
    File.exist? "#{full_public_template_path}.html.erb"
  end

  def valid_template

    if template_name && template_exists?
      public_template_path
    else
      File.join(PUBLIC_TEMPLATE_PATH, 'standard_template')
    end
  end

  def public_link
    "/#{node.unique_name}"
  end

  def ensure_preview_token!
    update!(preview_token: SecureRandom.urlsafe_base64(24)) unless preview_token.present?
    preview_token
  end

  def revoke_preview_token!
    update!(preview_token: nil)
  end

  def clone_attributes_from page
    return nil unless page

    self.reload
    page.translations.reload

    # Clone untranslated attributes
    self.tag_list         = page.tag_list
    self.template_name  ||= page.template_name
    self.published_at     = page.published_at

    # Clone translated attributes -- update each locale in place rather
    # than delete-and-recreate, so a locale whose content is genuinely
    # unchanged keeps its real created_at/updated_at instead of looking
    # freshly touched on every single save (which was silently defeating
    # Page.find_with_outdated_translations' whole staleness comparison).
    # search_vector is excluded deliberately: it's DB-trigger-maintained
    # from title/abstract, not real content, and comparing a precomputed
    # tsvector risked a false "changed" from representation noise alone.
    source_locales = page.translations.map(&:locale)
    self.translations.where.not(:locale => source_locales).destroy_all

    page.translations.each do |source_translation|
      attrs = source_translation.attributes.except("id", "page_id", "created_at", "updated_at", "search_vector")
      mine  = self.translations.find_by(:locale => source_translation.locale)

      if mine
        changed_attrs = attrs.reject { |k, v| mine.public_send(k) == v }
        mine.update!(changed_attrs) if changed_attrs.any?
      else
        self.translations.create!(attrs)
      end
    end

    # Clone asset references
    self.assets = page.assets

    self.save
  end

  def diff_against other, view: :inline, locale: nil
    if locale
      mine, theirs = translations.find_by(:locale => locale), other.translations.find_by(:locale => locale)
      my_title, my_abstract, my_body          = mine&.title,   mine&.abstract,   mine&.body
      their_title, their_abstract, their_body = theirs&.title, theirs&.abstract, theirs&.body
    else
      my_title, my_abstract, my_body          = title, abstract, body
      their_title, their_abstract, their_body = other.title, other.abstract, other.body
    end

    text_diffs =
      if view == :side_by_side
        {
          title:    HtmlWordDiff.side_by_side(their_title.to_s,    my_title.to_s),
          abstract: HtmlWordDiff.side_by_side(their_abstract.to_s, my_abstract.to_s),
          body:     HtmlWordDiff.side_by_side(their_body.to_s,     my_body.to_s)
        }
      else
        {
          title:    HtmlWordDiff.inline(their_title.to_s,    my_title.to_s),
          abstract: HtmlWordDiff.inline(their_abstract.to_s, my_abstract.to_s),
          body:     HtmlWordDiff.inline(their_body.to_s,     my_body.to_s)
        }
      end

    text_diffs.merge(
      tags:          { added: tag_list.to_a - other.tag_list.to_a, removed: other.tag_list.to_a - tag_list.to_a },
      template_name: { from: other.template_name, to: template_name, changed: template_name != other.template_name },
      assets:        { added: assets.to_a - other.assets.to_a, removed: other.assets.to_a - assets.to_a }
    )
  end

  def locale_diff_summary other
    (translated_locales | other.translated_locales).sort_by(&:to_s).map do |locale|
      mine   = translations.find_by(:locale => locale)
      theirs = other.translations.find_by(:locale => locale)
      {
        :locale       => locale,
        :exists_here  => mine.present?,
        :exists_there => theirs.present?,
        :changed      => mine.present? != theirs.present? ||
                          mine&.title != theirs&.title ||
                          mine&.abstract != theirs&.abstract ||
                          mine&.body != theirs&.body
      }
    end
  end

  def public?
    published_at.nil? ? true : published_at < Time.now
  end

  def effective_lang
    if translated_locales.empty?
      return 'de'
    elsif translated_locales.include?(I18n.locale)
      return I18n.locale
    else
      return translated_locales.first
    end
  end

  # Returns true if a page has translations where one of them is significantly
  # older than the other.
  # Takes the I18n.default locale and a second :locale to test if the
  # translations for the given locales exist and if their updated_at attributes
  # have a delta time that is greater than the specified :delta_time
  def outdated_translations? options = {}

    default_options = {
      :locale => :en,
      :delta_time => 23.hours
    }

    options = default_options.merge options

    translations = self.translations

    default = translations.find {|x| x.locale.to_s == I18n.default_locale.to_s }
    custom  = translations.find {|x| x.locale.to_s == options[:locale].to_s }

    if translations.size > 1 && default && custom
      difference = (default.updated_at - custom.updated_at).to_i.abs
      return (options[:delta_time].to_i.abs < difference)
    else
      return false
    end
  end

  def update_assets image_ids

    transaction do
      self.related_assets.delete_all

      if image_ids
        image_ids.each_with_index do |id, index|
          asset = Asset.find(id)
          self.related_assets.create!(:asset_id => asset.id, :position => index+1)
        end
      end
    end

  end

  # Installs (or re-installs) the trigger that keeps page_translations'
  # search_vector in sync. Idempotent, safe to call on every boot.
  # search_vector is populated by a raw Postgres trigger, not anything
  # Rails' schema dumper can represent -- a database rebuilt from
  # schema.rb rather than replayed migrations silently loses it.
  def self.ensure_search_vector_trigger!
    connection.execute(<<~SQL)
      CREATE OR REPLACE FUNCTION page_translations_search_vector_update()
      RETURNS trigger AS $$
      BEGIN
        NEW.search_vector := to_tsvector(
          'simple',
          coalesce(NEW.title, '') || ' ' ||
          coalesce(NEW.abstract, '') || ' ' ||
          coalesce(NEW.body, '')
        );
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE OR REPLACE TRIGGER page_translations_search_vector_trigger
      BEFORE INSERT OR UPDATE ON page_translations
      FOR EACH ROW EXECUTE PROCEDURE page_translations_search_vector_update();
    SQL
  end

  private

    def set_page_title
      self.title = "Untitled" if title.nil?
    end

    def set_template
      return if template_name.present?
      self.template_name = node&.default_template_name || (node&.update? ? "update" : nil)
    end

    def rewrite_links_in_body
      return unless self.body

      doc = Nokogiri::HTML::DocumentFragment.parse(self.body)
      locales = I18n.available_locales.reject { |l| l == :root }

      doc.css('a').each do |link|
        href = link['href']
        next unless href
        next if href.start_with?('http://', 'https://')
        next if href =~ /system\/uploads/

        unless locales.include?(href.slice(1, 2)&.to_sym)
          link['href'] = href.sub(/^\//, "/#{I18n.locale}/")
        end
      end

      self.body = doc.to_html
    end
end
