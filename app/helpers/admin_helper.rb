module AdminHelper
  def mtime_busted_path(path)
    file = Rails.public_path.join(path.sub(%r{\A/}, ""))
    raise "Static asset not found for cache-busting: #{path} (looked for #{file})" unless File.exist?(file)
    "#{path}?v=#{File.mtime(file).to_i}"
  end
end
