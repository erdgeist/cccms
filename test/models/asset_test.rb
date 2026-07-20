require 'test_helper'

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
end
