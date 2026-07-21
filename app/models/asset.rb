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
end
