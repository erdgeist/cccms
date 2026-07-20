require 'test_helper'

class AssetLicenseTest < ActiveSupport::TestCase
  test "find returns a populated entry for a known key" do
    entry = AssetLicense.find("cc_by_4")

    assert_equal "cc_by_4", entry.key
    assert_equal "https://creativecommons.org/licenses/by/4.0/", entry.url
    assert entry.requires_attribution
    assert_equal "license", entry.style
  end

  test "find returns nil for an unknown or blank key" do
    assert_nil AssetLicense.find("not_a_real_license")
    assert_nil AssetLicense.find(nil)
    assert_nil AssetLicense.find("")
  end

  test "keys includes every dictionary entry" do
    assert_includes AssetLicense.keys, "cc0"
    assert_includes AssetLicense.keys, "own_work"
  end

  test "a note-style entry has no attribution requirement and no url" do
    entry = AssetLicense.find("own_work")

    assert_not entry.requires_attribution
    assert_nil entry.url
    assert_equal "note", entry.style
  end
end
