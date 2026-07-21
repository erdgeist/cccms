namespace :assets do
  desc "Regenerate ImageMagick variants for every image asset from its stored original -- rerun whenever a new style is added to FileAttachment::STYLES after assets already exist. Scope to one asset first with ASSET_ID=123."
  task :regenerate_variants => :environment do
    scope = Asset.where(upload_content_type: FileAttachment::IMAGE_CONTENT_TYPES +
                                              FileAttachment::VECTOR_CONTENT_TYPES +
                                              FileAttachment::RASTERIZED_CONTENT_TYPES)
    scope = scope.where(id: ENV["ASSET_ID"]) if ENV["ASSET_ID"].present?

    scope.find_each do |asset|
      original_path = asset.send(:file_path, :original)

      unless File.exist?(original_path)
        puts "Skipping Asset##{asset.id} (#{asset.name}) -- no original file at #{original_path}"
        next
      end

      asset.send(:generate_all_variants, original_path)
      puts "Regenerated variants for Asset##{asset.id} (#{asset.name})"
    end
  end

desc "One-shot: flag each live page's current first-by-position image as its headline"
  task backfill_headline: :environment do
    count = 0
    page_ids = (Node.where.not(head_id: nil).pluck(:head_id) +
                Node.where.not(draft_id: nil).pluck(:draft_id)).uniq

    Page.where(id: page_ids).find_each do |page|
      next if page.related_assets.where(headline: true).exists?

      first_image = page.related_assets.joins(:asset).merge(Asset.images).order(:position).first
      next unless first_image

      first_image.update!(headline: true)
      count += 1
    end

    puts "Flagged #{count} pages' current first image as headline."
  end

end
