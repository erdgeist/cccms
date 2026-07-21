require 'test_helper'

class PagesControllerTest < ActionController::TestCase
  test "preview shows the autosave when a draft and an autosave both exist" do
    login_as :quentin

    node = Node.root.children.create!(:slug => "preview_retest")
    node.draft.update!(:title => "draft title")
    node.publish_draft!

    node.draft
    node.lock_for_editing!(users(:quentin))
    node.autosave!({ :title => "draft title" }, users(:quentin))
    node.save_draft!(users(:quentin))
    node.autosave!({ :title => "autosave title" }, users(:quentin))

    get :preview, params: { :id => node.draft_id }

    assert_response :success
    assert_match "autosave title", response.body
  end

  test "preview renders a headlined image on the autosave without crashing" do
    login_as :quentin

    node = Node.root.children.create!(:slug => "preview_retest_with_image")
    node.lock_for_editing!(users(:quentin))
    node.autosave!({ :title => "draft title" }, users(:quentin))
    node.save_draft!(users(:quentin))
    node.autosave!({ :title => "autosave title" }, users(:quentin))

    asset = Asset.create!(:name => "test", :upload_content_type => "image/png")
    node.autosave.related_assets.create!(:asset_id => asset.id, :position => 1, :headline => true)

    get :preview, params: { :id => node.draft_id }

    assert_response :success
    assert_match "autosave title", response.body
  end

  test "preview shows the autosave when no draft exists at all" do
    login_as :quentin

    node = Node.root.children.create!(:slug => "preview_retest_no_draft")
    node.draft.destroy
    node.update_column(:draft_id, nil)

    node.lock_for_editing!(users(:quentin))
    node.autosave!({ :title => "autosave only title" }, users(:quentin))

    asset = Asset.create!(:name => "test", :upload_content_type => "image/png")
    node.autosave.related_assets.create!(:asset_id => asset.id, :position => 1)

    get :preview, params: { :id => node.autosave_id }

    assert_response :success
    assert_match "autosave only title", response.body
  end

  test "preview shows head normally when there is no draft or autosave" do
    login_as :quentin

    node = Node.root.children.create!(:slug => "preview_retest_head_only")
    node.draft.update!(:title => "head title")
    node.publish_draft!

    get :preview, params: { :id => node.head_id }

    assert_response :success
    assert_match "head title", response.body
  end
end
