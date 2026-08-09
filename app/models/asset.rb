class Asset < ApplicationRecord
  IMAGE_CONTENT_TYPES = ["image/gif", "image/jpeg", "image/png", "image/webp"]
  PDF_CONTENT_TYPE = "application/pdf"

  include FileAttachment
  
  has_many :related_assets, :dependent => :destroy
  has_many :pages, :through => :related_assets

  scope :images,    -> { where(:upload_content_type => IMAGE_CONTENT_TYPES) }
  scope :documents, -> { where(:upload_content_type => ["application/pdf", "text/plain", "text/rtf"]) }
  scope :audio,     -> { where(:upload_content_type => ["audio/mpeg", "audio/x-m4a", "audio/wav", "audio/x-wav"]) }
  scope :pdfs,      -> { where(:upload_content_type => PDF_CONTENT_TYPE) }

  scope :headline_eligible, -> { where(:upload_content_type => IMAGE_CONTENT_TYPES + [PDF_CONTENT_TYPE]) }

  validates :license_key, inclusion: { in: -> { AssetLicense.keys } }, allow_blank: true

  def image?
    IMAGE_CONTENT_TYPES.include?(upload_content_type)
  end

  def pdf?
    upload_content_type == PDF_CONTENT_TYPE
  end

  def has_credit?
    creator.present? || source_url.present? || license_key.present?
  end

  def show_credit?
    image? && has_credit?
  end

  # Nodes whose current lifecycle rows (head, draft or autosave) carry
  # this asset. Historical revisions also hold RelatedAsset rows; they
  # are excluded by construction here, since nothing points at them.
  def attached_nodes
    page_ids = related_assets.select(:page_id)
    Node.where("head_id IN (:ids) OR draft_id IN (:ids) OR autosave_id IN (:ids)",
               :ids => page_ids).distinct
  end

  # Witnessed destruction, refused while the asset is attached to any
  # current row. Detaching stays an in-editor act, so nothing
  # destroyed here is carried by a page. The entry is still warranted:
  # the original and its variants are reachable under /system/uploads
  # until the row and its files die.
  def destroy_witnessed! user:
    if attached_nodes.any?
      errors.add(:base, :destroy_while_attached)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    ActiveRecord::Base.transaction do
      NodeAction.record!(:participants => [self], :user => user,
                          :action       => "asset_destroy",
                          :asset_name   => name,
                          :content_type => upload_content_type,
                          :path         => upload.url.sub(/\?\d+$/, ""))
      destroy!
    end
  end

  def self.editor_search(term)
    words = term.to_s.split(/\s+/).reject(&:blank?)
    return none if words.empty?

    words.inject(all) do |scope, word|
      like = "%#{sanitize_sql_like(word)}%"
      scope.where(
        "assets.name ILIKE :t OR assets.creator ILIKE :t OR " \
        "assets.upload_file_name ILIKE :t OR assets.source_url ILIKE :t OR " \
        "assets.upload_content_type ILIKE :t", :t => like
      )
    end
  end
end
