module AdminHelper

  def language_selector
    case I18n.locale
    when :de
      link_to raw('<span class="inactive">English</span>'), url_for(params.permit(:locale, :page_path).to_h.merge('locale' => 'en'))
    when :en
      link_to raw('<span class="inactive">English</span>'), url_for(params.permit(:locale, :page_path).to_h.merge('locale' => 'de'))
    end
  end

  def mtime_busted_path(path)
    file = Rails.public_path.join(path.sub(%r{\A/}, ""))
    raise "Static asset not found for cache-busting: #{path} (looked for #{file})" unless File.exist?(file)
    "#{path}?v=#{File.mtime(file).to_i}"
  end
end
