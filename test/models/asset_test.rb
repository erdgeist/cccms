require 'test_helper'
require "rack/test/uploaded_file"

class AssetTest < ActiveSupport::TestCase
  
  test "related assets get destroyed when assets get destroyed" do
    Asset.delete_all
    RelatedAsset.delete_all
    
    assert asset  = Asset.create
    assert node   = Node.root.children.create( :slug => "asset" )
    assert_equal [], node.draft.assets
    
    draft = node.draft
    draft.assets << asset
    assert_equal 1, draft.assets.length
    
    asset.destroy
    draft.reload
    assert_equal 0, draft.assets.length
    assert_equal 0, RelatedAsset.count
  end

  test "image? is true for supported image content types" do
    assert Asset.new(:upload_content_type => "image/png").image?
    assert Asset.new(:upload_content_type => "image/jpeg").image?
  end

  test "image? is false for non-image content types" do
    assert_not Asset.new(:upload_content_type => "application/pdf").image?
    assert_not Asset.new(:upload_content_type => nil).image?
  end

  test "license_key must be a known dictionary key" do
    asset = Asset.new(:license_key => "not_a_real_license")
    I18n.with_locale(:en) do
      assert_not asset.valid?
      assert_includes asset.errors[:license_key], "is not included in the list"
    end
  end

  test "license_key may be blank" do
    assert Asset.new(:license_key => nil).valid?
  end  

  test "pdf? is true only for application/pdf" do
    assert Asset.new(:upload_content_type => "application/pdf").pdf?
    assert_not Asset.new(:upload_content_type => "image/png").pdf?
  end

  test "show_credit? is false for a PDF even with every credit field present" do
    asset = Asset.new(:name => "demo", :upload_content_type => "application/pdf",
                       :creator => "Jane Doe", :source_url => "https://example.org", :license_key => "cc_by_4")
    assert asset.has_credit?
    assert_not asset.show_credit?
  end

  test "an upload that claims to be an image but is not is refused" do
    Tempfile.create(["fake", ".jpg"]) do |f|
      f.write("this is not a jpeg")
      f.flush

      asset = Asset.new(:name => "fake")
      asset.upload = Rack::Test::UploadedFile.new(f.path, "image/jpeg")

      assert_not asset.valid?
      assert_includes asset.errors.full_messages.to_sentence,
                      I18n.t("activerecord.errors.models.asset.attributes.upload.unreadable_image")
    end
  end

  test "a real image is accepted and its type comes from the file" do
    asset = Asset.new(:name => "real")
    asset.upload = Rack::Test::UploadedFile.new(file_fixture("test_image.png"), "image/jpeg")

    assert asset.valid?, asset.errors.full_messages.to_sentence
    assert_equal "image/png", asset.upload_content_type
  end
end
