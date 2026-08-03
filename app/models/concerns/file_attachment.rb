require "open3"

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

module FileAttachment
  extend ActiveSupport::Concern

  STYLES = {
    medium:   { args: ["-resize", "300x300>"] },
    thumb:    { args: ["-resize", "100x100>"] },
    headline: { args: ["-resize", "460x250^", "-gravity", "center", "-extent", "460x250"] },
    large:    { args: ["-resize", "1600x1600>"] }
  }.freeze

  # Prepended to ImageMagick's configuration search path on every
  # invocation, so config/imagemagick/policy.xml is read before the
  # installed one. Per-invocation rather than in the environment, so it
  # cannot leak into anything else on the host.
  MAGICK_ENV = {
    "MAGICK_CONFIGURE_PATH" => Rails.root.join("config", "imagemagick").to_s
  }.freeze

  # ImageMagick picks its decoder from the file, not from the multipart
  # header. Where the two disagree, believe ImageMagick: otherwise
  # generate_all_variants dispatches on a claim and hands a file to a
  # pipeline built for something else.
  MAGICK_FORMAT_CONTENT_TYPES = {
    "JPEG" => "image/jpeg",
    "PNG"  => "image/png",
    "GIF"  => "image/gif",
    "WEBP" => "image/webp",
    "SVG"  => "image/svg+xml",
    "MSVG" => "image/svg+xml",
    "PDF"  => "application/pdf"
  }.freeze

  IMAGE_CONTENT_TYPES    = %w[image/jpeg image/gif image/png image/webp].freeze
  VECTOR_CONTENT_TYPES   = %w[image/svg+xml].freeze
  RASTERIZED_CONTENT_TYPES = %w[application/pdf].freeze
  DISPLAYABLE_AS_IMAGE   = IMAGE_CONTENT_TYPES + VECTOR_CONTENT_TYPES

  # ---- Social card (:og variant) -------------------------------------
  #
  # 1200x630 is the de facto standard: Facebook codified it and Discord,
  # Slack, WhatsApp, LinkedIn, Bluesky, Threads and Mastodon all render it
  # as a full-width card.
  OG_WIDTH  = 1200
  OG_HEIGHT = 630

  # public/images/social_card.png carries ground, knot and wordmark as
  # pixels. Code only fits a source into the slot and draws the paper edge
  # and drop shadow, whose outline follows each source's shape and so
  # cannot be baked into the template.
  OG_TEMPLATE = Rails.root.join("public", "images", "social_card.png")

  # The paper rectangle in template pixels, origin top-left, measured
  # WITHOUT the shadow. If the template's layout changes, this changes with
  # it in the same commit -- there is no way for code to detect a mismatch.
  OG_SLOT = { :x => 75, :y => 70, :width => 346, :height => 490 }.freeze

  # Hairline around the page, so a white document separates from the
  # ground. #CACACA is ccc.css's --paper-edge at full opacity.
  OG_PAPER_EDGE   = "#CACACA"
  OG_PAPER_BORDER = 3

  # ImageMagick -shadow: opacity percent x sigma, then offset. Sigma 10
  # spreads about 20px, plus the 6px drop, so 40px of margin around the
  # slot holds it comfortably.
  OG_SHADOW        = "50x10+0+6"
  OG_SHADOW_MARGIN = 40

  OG_GROUND = "#4D4D4D"

  # Photographs at least this wide relative to their height fill the frame
  # edge to edge; losing 12% of a 3:2 photo's height is invisible. Anything
  # squarer or taller goes on the template, where the ground does the work
  # that cropping would otherwise do by discarding content. Documents never
  # crop regardless of shape -- the whole page is the message.
  OG_CROP_RATIO = 1.5


  included do
    attr_reader :upload

    after_initialize :build_upload_proxy
    after_save       :process_upload
    before_destroy   :delete_upload_files
    validate         :upload_must_be_readable_when_it_claims_to_be_an_image
  end

  def upload=(uploaded_file)
    return if uploaded_file.blank?
    @pending_upload = uploaded_file
    # Populate the database columns immediately so validations can use them
    self.upload_file_name    = sanitize_filename(uploaded_file.original_filename)
    detected = detected_content_type(uploaded_file)
    @upload_unreadable = detected.nil?
    self.upload_content_type = detected ||
                               uploaded_file.content_type.to_s.split(';').first.strip
    self.upload_file_size    = uploaded_file.size
    self.upload_updated_at   = Time.current
    build_upload_proxy
  end

  def has_variant?(style)
    upload_file_name.present? && File.exist?(file_path(style))
  end

  def previewable?
    has_variant?(:medium)
  end

  def variant_filename(style)
    return upload_file_name if style == :original

    base = File.basename(upload_file_name, ".*")

    # Rasterised sources are PNG in every style
    return "#{base}.png" if RASTERIZED_CONTENT_TYPES.include?(upload_content_type)

    if style == :og
      return VECTOR_CONTENT_TYPES.include?(upload_content_type) ? "#{base}.png" : "#{base}.jpg"
    end

    upload_file_name
  end

  private

  def build_upload_proxy
    @upload = UploadProxy.new(self)
  end

  class_methods do
    def upload_root
      Rails.env.test? ? Rails.root.join("tmp", "test_uploads") : Rails.root.join("public", "system", "uploads")
    end
  end

  def upload_root
    self.class.upload_root
  end

  def process_upload
    return unless @pending_upload
    uploaded_file = @pending_upload
    @pending_upload = nil

    old_dir = upload_root.join(id.to_s)

    FileUtils.rm_rf(old_dir) if Dir.exist?(old_dir)

    original_path = file_path(:original)
    FileUtils.mkdir_p(File.dirname(original_path))
    FileUtils.cp(uploaded_file.tempfile.path, original_path)

    generate_all_variants(original_path)
  end

  def generate_variants(original_path, extra_args = [])
    STYLES.each do |style, options|
      dest_path = file_path(style)
      FileUtils.mkdir_p(File.dirname(dest_path))
      if !system(MAGICK_ENV, "magick", original_path, *extra_args, *options[:args], dest_path)
        Rails.logger.warn("Asset##{id}: magick failed for #{style} of #{upload_file_name}")
      end
    end
  end

  def generate_svg_variants(original_path)
    STYLES.each do |style, _|
      dest_path = file_path(style)
      FileUtils.mkdir_p(File.dirname(dest_path))
      FileUtils.cp(original_path, dest_path)
    end
  end

  # 1200x630 social card. Landscape photographs fill the frame; documents,
  # vector art and portrait images sit on the template with a paper edge and
  # a drop shadow. Always opaque: a transparent PNG renders unreadable in
  # dark-mode clients, which bleed their own background through.
  def generate_og_variant(original_path)
    dest_path = file_path(:og)
    FileUtils.mkdir_p(File.dirname(dest_path))

    ok = if og_full_bleed?(original_path)
      system(MAGICK_ENV, "magick", "#{original_path}[0]",
             "-resize", "#{OG_WIDTH}x#{OG_HEIGHT}^",
             "-gravity", "center", "-extent", "#{OG_WIDTH}x#{OG_HEIGHT}",
             "-background", OG_GROUND, "-alpha", "remove", "-alpha", "off",
             *og_output_args, dest_path)
    else
      system(MAGICK_ENV, *og_template_command(dest_path))
    end

    Rails.logger.warn("Asset##{id}: magick failed for og of #{upload_file_name}") unless ok
    ok
  end

  def generate_all_variants(original_path)
    if IMAGE_CONTENT_TYPES.include?(upload_content_type)
      generate_variants(original_path)
    elsif VECTOR_CONTENT_TYPES.include?(upload_content_type)
      generate_svg_variants(original_path)
    elsif RASTERIZED_CONTENT_TYPES.include?(upload_content_type)
      unless source_dimensions(original_path)
        Rails.logger.warn("Asset##{id}: #{upload_file_name} has no rasterisable first page, skipping variants")
        return false
      end

      generate_variants("#{original_path}[0]",
                        ["-background", "white", "-alpha", "remove", "-alpha", "off"])
    else
      # Not displayable as an image at all: no variants, no card.
      return false
    end

    generate_og_variant(original_path)
    true
  end

  def source_dimensions(path)
    out, err, status = Open3.capture3(MAGICK_ENV, "magick", "identify", "-format", "%w %h", "#{path}[0]")
    unless status.success?
      Rails.logger.warn("Asset##{id}: magick identify failed for #{path}: #{err.lines.first&.strip}")
      return nil
    end

    width, height = out.split.map(&:to_i)
    (width.positive? && height.positive?) ? [width, height] : nil
  rescue Errno::ENOENT
    nil
  end

  # True when the source should fill the whole 1200x630 frame rather than
  # sit on the template
  def og_full_bleed?(path)
    return false unless IMAGE_CONTENT_TYPES.include?(upload_content_type)

    dimensions = source_dimensions(path)
    return false unless dimensions

    (dimensions[0].to_f / dimensions[1]) >= OG_CROP_RATIO
  end

  # Fits the source into OG_SLOT, borders it, drops a shadow behind it, then
  # pastes the result onto the template. OG_SLOT is the paper rectangle
  # without the shadow, so the layer is padded by OG_SHADOW_MARGIN on every
  # side and pasted that much up and to the left -- which keeps the paper
  # itself exactly where it was measured.
  def og_template_command(dest_path)
    rasterized = RASTERIZED_CONTENT_TYPES.include?(upload_content_type)
    original   = file_path(:original)

    # -density must precede the input filename to affect PDF rasterisation,
    # which is why this cannot be a STYLES entry: that loop puts all
    # arguments after the input. 150dpi gives A4 about 1240x1754, ample for
    # a 490px-tall thumbnail.
    density = rasterized ? ["-density", "150"] : []
    source  = rasterized ? "#{original}[0]" : original
    flatten = rasterized ? ["-background", "white", "-alpha", "remove", "-alpha", "off"] : []

    paper    = "#{OG_SLOT[:width]}x#{OG_SLOT[:height]}"
    envelope = "#{OG_SLOT[:width] + 2 * OG_SHADOW_MARGIN}x#{OG_SLOT[:height] + 2 * OG_SHADOW_MARGIN}"
    paste_x  = OG_SLOT[:x] - OG_SHADOW_MARGIN
    paste_y  = OG_SLOT[:y] - OG_SHADOW_MARGIN

    ["magick", OG_TEMPLATE.to_s,
     "(", *density, source, *flatten,
          # > means a source smaller than the slot stays at native size
          # rather than being upscaled into softness.
          "-resize", "#{paper}>",
          "-bordercolor", OG_PAPER_EDGE, "-border", OG_PAPER_BORDER.to_s,
          "(", "+clone", "-background", "black", "-shadow", OG_SHADOW, ")",
          "+swap", "-background", "none", "-layers", "merge", "+repage",
          "-background", "none", "-gravity", "center", "-extent", envelope,
     ")",
     "-gravity", "northwest", "-geometry", "+#{paste_x}+#{paste_y}",
     "-composite",
     "-background", OG_GROUND, "-alpha", "remove", "-alpha", "off",
     *og_output_args, dest_path]
  end

  def og_output_args
    if RASTERIZED_CONTENT_TYPES.include?(upload_content_type) ||
       VECTOR_CONTENT_TYPES.include?(upload_content_type)
      # PNG without palette reduction: the drop shadow is a smooth alpha
      # ramp, and quantising it dithers into visible speckle along the
      # edge. JPEG is no better here, since it rings around the small
      # black-on-white text of a document page.
      ["-define", "png:compression-level=9", "-strip"]
    else
      # -strip also removes EXIF, so a headline photograph's camera model
      # and GPS coordinates do not travel to every platform that fetches
      # the card.
      ["-quality", "82", "-sampling-factor", "4:4:4", "-strip"]
    end
  end

  def detected_content_type(uploaded_file)
    path = uploaded_file.try(:tempfile).try(:path) || uploaded_file.try(:path)
    return nil if path.blank? || !File.exist?(path)

    out, _err, status = Open3.capture3(MAGICK_ENV, "magick", "identify", "-format", "%m", "#{path}[0]")
    return nil unless status.success?

    MAGICK_FORMAT_CONTENT_TYPES[out.strip.upcase]
  rescue StandardError
    nil
  end

  def delete_upload_files
    dir = upload_root.join(id.to_s)
    FileUtils.rm_rf(dir) if Dir.exist?(dir)
  end

  def upload_must_be_readable_when_it_claims_to_be_an_image
    return unless @upload_unreadable
    return unless IMAGE_CONTENT_TYPES.include?(upload_content_type)

    errors.add(:upload, :unreadable_image)
  end

  def file_path(style)
    upload_root.join(id.to_s, style.to_s, variant_filename(style)).to_s
  end

  def sanitize_filename(filename)
    name = File.basename(filename).unicode_normalize(:nfc)
    name.gsub(/(?u)[^\w\.\-]/, '_')
  end

  # Proxy object returned by asset.upload, providing the Paperclip-compatible
  # interface used in views: .url, .url(:style), .content_type, .size
  class UploadProxy
    def initialize(record)
      @record = record
    end

    def url(style = :original)
      return "" if @record.upload_file_name.blank?
      "/system/uploads/#{@record.id}/#{style}/#{@record.variant_filename(style)}"
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
