class AssetLicense
  Entry = Struct.new(:key, :url, :requires_attribution, :style, keyword_init: true)

  DICTIONARY = YAML.load_file(Rails.root.join("config", "asset_licenses.yml")).freeze

  def self.keys
    DICTIONARY.keys
  end

  def self.find(key)
    entry = DICTIONARY[key.to_s] if key.present?
    return nil unless entry
    Entry.new(key: key.to_s, url: entry["url"], requires_attribution: entry["requires_attribution"], style: entry["style"])
  end
end
