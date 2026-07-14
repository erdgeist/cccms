require 'test_helper'

class SharedPreviewsControllerTest < ActionController::TestCase
  test "renders the preview for a draft that is current but not yet head" do
    node = Node.root.children.create!(:slug => "shared_preview_draft_test")
    node.draft.ensure_preview_token!

    get :show, params: { :token => node.draft.preview_token }

    assert_response :success
  end

  test "renders the preview for a brand-new draft on an already-published node" do
    node = Node.root.children.create!(:slug => "shared_preview_published_node_test")
    node.publish_draft!
    find_or_create_draft(node, User.first)
    node.draft.ensure_preview_token!

    get :show, params: { :token => node.draft.preview_token }

    assert_response :success
  end

  test "redirects to the live page once the previewed draft has been published and become head" do
    node = Node.root.children.create!(:slug => "shared_preview_now_head_test")
    node.draft.ensure_preview_token!
    token = node.draft.preview_token

    node.publish_draft!

    get :show, params: { :token => token }

    assert_redirected_to node.head.public_link
  end
end
