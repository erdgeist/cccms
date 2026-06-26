require 'xml'

class Page < ApplicationRecord

  PUBLIC_TEMPLATE_PATH = File.join(%w(custom page_templates public))
  FULL_PUBLIC_TEMPLATE_PATH = Rails.root.join('app', 'views', PUBLIC_TEMPLATE_PATH)

  # Mixins and Plugins
  acts_as_taggable
  acts_as_list :column => :revision, :scope => :node_id

  translates :title, :abstract, :body # Globalize2

  # Associations
  belongs_to :node
  belongs_to :user
  belongs_to :editor, :class_name => "User"
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

    scope.order("#{options[:order_by]} #{options[:order_direction]}")
      .paginate(:page => page, :per_page => options[:limit])
  end

  def self.custom_templates
    files = Dir.entries(FULL_PUBLIC_TEMPLATE_PATH).select do |x|
      x if x.gsub!(".html.erb", "")
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

  def clone_attributes_from page
    return nil unless page

    self.reload

    # Clone untranslated attributes
    self.tag_list         = page.tag_list
    self.template_name  ||= page.template_name
    self.published_at     = page.published_at

    # Getting rid of the auto-generated empty translations
    self.translations.delete_all

    # Clone translated attributes
    page.translations.each do |translation|
      self.translations.create!(translation.attributes.except("id", "page_id", "created_at", "updated_at"))
    end

    # Clone asset references
    self.assets = page.assets

    self.save
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

  private

    def set_page_title
      if title.nil?
        title = "Untitled"
      end
    end

    def set_template
      if node && node.update?
        self.template_name = "update"
      end
    end

    def rewrite_links_in_body
      begin
        if self.body
          tmp_body    = "<div>#{self.body}</div>"
          xml_string  = XML::Parser.string( tmp_body )
          xml_doc     = xml_string.parse
          links       = xml_doc.find("//a[not(starts-with(@href, 'http://'))]")
          links       = links.reject { |l| l[:href] =~ /system\/uploads/ }
          locales     = I18n.available_locales.reject {|l| l == :root}

          if xml_doc.find("//p/aggregate")[0]
            aggregate_tags   = xml_doc.find("//aggregate")
            aggregate_tags[0].parent.replace_with aggregate_tags[0]
          end

          links.each do |link|
            unless locales.include? link[:href].slice(1,2).to_sym
              unless link[:href] =~ /sytem\/uploads/
                link[:href] = link[:href].sub(/^\//, "/#{I18n.locale}/")
              end
            end
          end

          tmp_body = xml_doc.to_s.gsub(/(\n\<div\>|\<\/div\>\n)/, "")
          tmp_body.gsub!("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "")

          self.body = tmp_body
        end
      rescue
        nil
      end
    end

end
