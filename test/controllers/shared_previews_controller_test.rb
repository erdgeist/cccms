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

  test "a shared preview emits no social metadata and is not indexable" do
    node = Node.root.children.create!(:slug => "shared_preview_no_og_test")
    node.draft.update!(:title => "Unveröffentlichter Entwurf")
    node.draft.ensure_preview_token!

    get :show, params: { :token => node.draft.preview_token }

    assert_response :success

    # An unfurled preview link would otherwise hand the draft's title,
    # abstract and headline image to everyone in the chat room.
    assert_select "meta[property^='og:']", false, "a preview must emit no og tags"
    assert_select "meta[name=robots][content=?]", "noindex, nofollow"
  end
end
