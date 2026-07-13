require 'test_helper'

class RelatedAssetsControllerTest < ActionController::TestCase
  test "search finds assets by name, excluding ones already attached" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_search_test")

    attached = Asset.create!(:name => "biometrics-scan", :upload_content_type => "image/png")
    node.draft.assets << attached

    Asset.create!(:name => "biometrics-poster", :upload_content_type => "image/png")
    Asset.create!(:name => "chaostreff-flyer", :upload_content_type => "image/png")

    get :search, params: { :node_id => node.id, :search_term => "biometrics" }

    json = JSON.parse(response.body)
    names = json.map { |a| a["name"] }
    assert_includes names, "biometrics-poster"
    assert_not_includes names, "biometrics-scan"
    assert_not_includes names, "chaostreff-flyer"
  end

  test "search with a blank term returns the most recently created assets" do
    Asset.delete_all
    RelatedAsset.delete_all
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_recent_test")

    Asset.create!(:name => "older-photo", :upload_content_type => "image/png", :created_at => 2.days.ago)
    Asset.create!(:name => "newer-photo", :upload_content_type => "image/png", :created_at => 1.hour.ago)

    get :search, params: { :node_id => node.id, :search_term => "" }

    json = JSON.parse(response.body)
    assert_equal ["newer-photo", "older-photo"], json.map { |a| a["name"] }
  end

  test "create attaches an asset to the node's editable page" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_create_test")
    asset = Asset.create!(:name => "erfa-photo", :upload_content_type => "image/png")

    post :create, params: { :node_id => node.id, :asset_id => asset.id }

    assert_response :success
    assert_includes node.draft.reload.related_assets.map(&:asset_id), asset.id
    json = JSON.parse(response.body)
    assert json["url"].present?
  end

  test "create does not duplicate an already-attached asset" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_dup_test")
    asset = Asset.create!(:name => "erfa-photo-2", :upload_content_type => "image/png")
    node.draft.assets << asset

    post :create, params: { :node_id => node.id, :asset_id => asset.id }

    assert_response :success
    assert_equal 1, node.draft.reload.related_assets.count
  end

  test "destroy removes the attached asset" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_destroy_test")
    asset = Asset.create!(:name => "old-photo", :upload_content_type => "image/png")
    node.draft.assets << asset
    related = node.draft.related_assets.first

    delete :destroy, params: { :node_id => node.id, :id => related.id }

    assert_response :success
    assert_equal 0, node.draft.reload.related_assets.count
  end

  test "update reorders the attached assets" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_reorder_test")
    first  = Asset.create!(:name => "first-photo", :upload_content_type => "image/png")
    second = Asset.create!(:name => "second-photo", :upload_content_type => "image/png")
    node.draft.assets << first
    node.draft.assets << second

    second_related = node.draft.related_assets.find_by(:asset_id => second.id)
    patch :update, params: { :node_id => node.id, :id => second_related.id, :position => 1 }

    assert_response :success
    ordered_asset_ids = node.draft.reload.related_assets.map(&:asset_id)
    assert_equal [second.id, first.id], ordered_asset_ids
  end
end
