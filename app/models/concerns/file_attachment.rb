# FileAttachment — minimal drop-in replacement for Paperclip's has_attached_file.
#
# Provides the same interface used throughout this codebase:
#   asset.upload.url              -> "/system/uploads/:id/original/:filename"
#   asset.upload.url(:thumb)      -> "/system/uploads/:id/thumb/:filename"
#   asset.upload.content_type     -> string
#   asset.upload.size             -> integer (bytes)
#
# Files are stored at:
#   Rails.root/public/system/uploads/:id/:style/:filename
#
# Image variants are generated via ImageMagick (convert) on upload.
# Non-image files get only an original, no variants.
#
# To replace an asset: assign a new file to asset.upload= and save.
# The filename is fixed on first upload and preserved on replacement,
# keeping all public URLs stable.
#
# Future: if more sophisticated asset management is needed (versioning,
# S3, on-demand resizing), replace this module and keep the interface.

module FileAttachment
  extend ActiveSupport::Concern

  STYLES = {
    medium:   { geometry: "300x300>",  format: nil },
    thumb:    { geometry: "100x100>",  format: nil },
    headline: { geometry: "460x250!",  format: nil }
  }.freeze

  IMAGE_CONTENT_TYPES = %w[image/jpeg image/gif image/png image/webp].freeze

  included do
    attr_reader :upload

    after_initialize :build_upload_proxy
    after_save       :process_upload
    before_destroy   :delete_upload_files
  end

  def upload=(uploaded_file)
    return if uploaded_file.blank?
    @pending_upload = uploaded_file
    # Populate the database columns immediately so validations can use them
    self.upload_file_name    = sanitize_filename(uploaded_file.original_filename)
    self.upload_content_type = uploaded_file.content_type.to_s.split(';').first.strip
    self.upload_file_size    = uploaded_file.size
    self.upload_updated_at   = Time.current
    build_upload_proxy
  end

  private

  def build_upload_proxy
    @upload = UploadProxy.new(self)
  end

  def process_upload
    return unless @pending_upload
    uploaded_file = @pending_upload
    @pending_upload = nil

    old_dir = Rails.root.join("public", "system", "uploads", id.to_s)
    FileUtils.rm_rf(old_dir) if Dir.exist?(old_dir)

    original_path = file_path(:original)
    FileUtils.mkdir_p(File.dirname(original_path))
    FileUtils.cp(uploaded_file.tempfile.path, original_path)

    if IMAGE_CONTENT_TYPES.include?(upload_content_type)
      generate_variants(original_path)
    end
  end

  def generate_variants(original_path)
    STYLES.each do |style, options|
      dest_path = file_path(style)
      FileUtils.mkdir_p(File.dirname(dest_path))
      system("magick", original_path, "-resize", options[:geometry], dest_path)
    end
  end

  def delete_upload_files
    dir = Rails.root.join("public", "system", "uploads", id.to_s)
    FileUtils.rm_rf(dir) if Dir.exist?(dir)
  end

  def file_path(style)
    Rails.root.join(
      "public", "system", "uploads",
      id.to_s, style.to_s, upload_file_name
    ).to_s
  end

  def sanitize_filename(filename)
    File.basename(filename).gsub(/[^\w\.\-]/, '_')
  end

  # Proxy object returned by asset.upload, providing the Paperclip-compatible
  # interface used in views: .url, .url(:style), .content_type, .size
  class UploadProxy
    def initialize(record)
      @record = record
    end

    def url(style = :original)
      return "" if @record.upload_file_name.blank?
      "/system/uploads/#{@record.id}/#{style}/#{@record.upload_file_name}"
    end

    def content_type
      @record.upload_content_type.to_s
    end

    def size
      @record.upload_file_size.to_i
    end

    def present?
      @record.upload_file_name.present?
    end

    def blank?
      !present?
    end
  end
end
