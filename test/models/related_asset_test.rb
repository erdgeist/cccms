require 'test_helper'

class RelatedAssetTest < ActiveSupport::TestCase
  test "headline can be set on an image asset" do
    node = Node.root.children.create!(:slug => "related_asset_headline_image_test")
    asset = Asset.create!(:name => "photo", :upload_content_type => "image/png")
    node.draft.assets << asset
    related = node.draft.related_assets.find_by(:asset_id => asset.id)

    related.headline = true
    assert related.valid?
  end

  test "headline can be set on a PDF asset" do
    node = Node.root.children.create!(:slug => "related_asset_headline_pdf_test")
    asset = Asset.create!(:name => "expert opinion", :upload_content_type => "application/pdf")
    node.draft.assets << asset
    related = node.draft.related_assets.find_by(:asset_id => asset.id)

    related.headline = true
    assert related.valid?
  end

  test "headline cannot be set on a non-image, non-PDF asset" do
    node = Node.root.children.create!(:slug => "related_asset_headline_text_test")
    asset = Asset.create!(:name => "programme", :upload_content_type => "text/plain")
    node.draft.assets << asset
    related = node.draft.related_assets.find_by(:asset_id => asset.id)

    related.headline = true
    assert_not related.valid?
    assert_includes related.errors[:headline], I18n.t("activerecord.errors.models.related_asset.attributes.headline.images_and_pdfs_only")
  end

  test "the headline validation does not raise when asset is missing" do
    related = RelatedAsset.new(:headline => true)
    assert_not related.valid?
  end

  test "at most one headline per page is enforced at the database level" do
    node = Node.root.children.create!(:slug => "related_asset_headline_uniqueness_test")
    first  = Asset.create!(:name => "first", :upload_content_type => "image/png")
    second = Asset.create!(:name => "second", :upload_content_type => "image/png")
    node.draft.assets << first
    node.draft.assets << second

    node.draft.related_assets.find_by(:asset_id => first.id).update!(:headline => true)
    second_related = node.draft.related_assets.find_by(:asset_id => second.id)

    assert_raises(ActiveRecord::RecordNotUnique) do
      RelatedAsset.where(:id => second_related.id).update_all(:headline => true)
    end
  end
end
