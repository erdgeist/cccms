namespace :assets do
  desc "Regenerate ImageMagick variants for every image asset from its stored original -- rerun whenever a new style is added to FileAttachment::STYLES after assets already exist. Scope to one asset first with ASSET_ID=123."
  task :regenerate_variants => :environment do
    scope = Asset.images
    scope = scope.where(id: ENV["ASSET_ID"]) if ENV["ASSET_ID"].present?

    scope.find_each do |asset|
      original_path = asset.send(:file_path, :original)

      unless File.exist?(original_path)
        puts "Skipping Asset##{asset.id} (#{asset.name}) -- no original file at #{original_path}"
        next
      end

      asset.send(:generate_variants, original_path)
      puts "Regenerated variants for Asset##{asset.id} (#{asset.name})"
    end
  end
end
