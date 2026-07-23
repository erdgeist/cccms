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
    node.lock_for_editing!(users(:quentin))
    asset = Asset.create!(:name => "erfa-photo", :upload_content_type => "image/png")

    post :create, params: { :node_id => node.id, :asset_id => asset.id }

    assert_response :success
    current = node.reload.editable_page
    assert_equal node.autosave, current, "mutation should have created an autosave layer"
    assert_includes current.related_assets.map(&:asset_id), asset.id
    json = JSON.parse(response.body)
    assert json["url"].present?
    assert_empty node.draft.reload.related_assets, "the draft must stay untouched"
  end

  test "create does not duplicate an already-attached asset" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_dup_test")
    node.lock_for_editing!(users(:quentin))
    asset = Asset.create!(:name => "erfa-photo-2", :upload_content_type => "image/png")
    node.draft.assets << asset

    post :create, params: { :node_id => node.id, :asset_id => asset.id }

    assert_response :success
    assert_equal 1, node.draft.reload.related_assets.count
  end

  test "destroy removes the attached asset" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_destroy_test")
    node.lock_for_editing!(users(:quentin))
    asset = Asset.create!(:name => "old-photo", :upload_content_type => "image/png")
    node.draft.assets << asset

    related = node.draft.related_assets.first
    delete :destroy, params: { :node_id => node.id, :id => related.id }

    assert_response :success
    assert_equal 0, node.reload.editable_page.related_assets.count
    assert_equal 1, node.draft.reload.related_assets.count, "the draft must stay untouched"
  end

  test "update reorders the attached assets" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_reorder_test")
    node.lock_for_editing!(users(:quentin))
    first  = Asset.create!(:name => "first-photo", :upload_content_type => "image/png")
    second = Asset.create!(:name => "second-photo", :upload_content_type => "image/png")
    node.draft.assets << first
    node.draft.assets << second

    second_related = node.draft.related_assets.find_by(:asset_id => second.id)
    patch :update, params: { :node_id => node.id, :id => second_related.id, :position => 1 }

    assert_response :success
    ordered_asset_ids = node.reload.editable_page.related_assets.order(:position).map(&:asset_id)
    # XXXX ordered_asset_ids = node.draft.reload.related_assets.map(&:asset_id)
    assert_equal [second.id, first.id], ordered_asset_ids
  end

  test "update sets the headline flag" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_headline_test")
    node.lock_for_editing!(users(:quentin))
    asset = Asset.create!(:name => "headline-photo", :upload_content_type => "image/png")
    node.draft.assets << asset
    related = node.draft.related_assets.find_by(:asset_id => asset.id)

    patch :update, params: { :node_id => node.id, :id => related.id, :headline => "true" }

    assert_response :success
    assert node.reload.editable_page.related_assets.find_by!(:asset_id => asset.id).headline?
    assert_not related.reload.headline?, "the draft must stay untouched"
  end

  test "update with headline=true clears any previous headline on the same page" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_headline_swap_test")
    node.lock_for_editing!(users(:quentin))
    first  = Asset.create!(:name => "first-headline", :upload_content_type => "image/png")
    second = Asset.create!(:name => "second-headline", :upload_content_type => "image/png")
    node.draft.assets << first
    node.draft.assets << second

    first_related  = node.draft.related_assets.find_by(:asset_id => first.id)
    second_related = node.draft.related_assets.find_by(:asset_id => second.id)
    first_related.update!(:headline => true)

    patch :update, params: { :node_id => node.id, :id => second_related.id, :headline => "true" }

    assert_response :success
    current = node.reload.editable_page
    assert_not current.related_assets.find_by!(:asset_id => first.id).headline?
    assert current.related_assets.find_by!(:asset_id => second.id).headline?
    assert first_related.reload.headline?, "the draft must stay untouched"
  end

  test "update with headline=false clears the headline" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_headline_unset_test")
    node.lock_for_editing!(users(:quentin))
    asset = Asset.create!(:name => "unset-headline", :upload_content_type => "image/png")
    node.draft.assets << asset
    related = node.draft.related_assets.find_by(:asset_id => asset.id)
    related.update!(:headline => true)

    patch :update, params: { :node_id => node.id, :id => related.id, :headline => "false" }

    assert_response :success
    assert_not node.reload.editable_page.related_assets.find_by!(:asset_id => asset.id).headline?
    assert related.reload.headline?, "the draft must stay untouched"
  end

  test "search includes PDF assets as headline-eligible candidates" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_search_pdf_test")
    asset = Asset.create!(:name => "expert-opinion-searchable", :upload_content_type => "application/pdf")

    get :search, params: { :node_id => node.id, :search_term => "expert-opinion-searchable" }

    assert_response :success
    ids = JSON.parse(response.body).map { |r| r["id"] }
    assert_includes ids, asset.id
  end

  test "search matches by filename as well as name" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "related_assets_search_filename_test")
    asset = Asset.create!(:name => "Untitled", :upload_content_type => "application/pdf",
                           :upload_file_name => "Stellungnahme_Patientendaten_Schutz.pdf")

    get :search, params: { :node_id => node.id, :search_term => "Patientendaten" }

    assert_response :success
    ids = JSON.parse(response.body).map { |r| r["id"] }
    assert_includes ids, asset.id
  end

  test "curation without holding the lock is refused with 423" do
    login_as :quentin
    node  = Node.root.children.create!(:slug => "curation_lock_test")
    asset = Asset.create!(:name => "Untouchable", :upload_content_type => "image/png")
    node.lock_for_editing!(users(:aaron))

    post :create, params: { :node_id => node.id, :asset_id => asset.id }

    assert_response :locked
    assert_empty node.draft.assets.reload
  end
end
