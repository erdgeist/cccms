require 'test_helper'

class NodeActionsControllerTest < ActionController::TestCase

  def setup
    login_as :quentin
  end

  def logged_node slug, title
    node = Node.root.children.create!(:slug => slug)
    Globalize.with_locale(I18n.default_locale) { node.draft.update!(:title => title) }
    node
  end

  test "index renders" do
    get :index
    assert_response :success
  end

  test "index filters by node" do
    node_a = logged_node("log_filter_a", "Alpha Subject")
    node_b = logged_node("log_filter_b", "Beta Subject")
    NodeAction.record!(:node => node_a, :action => "create", :user => users(:quentin))
    NodeAction.record!(:node => node_b, :action => "create", :user => users(:quentin))

    get :index, params: { :node_id => node_a.id }

    assert_response :success
    assert_includes    @response.body, "Alpha Subject"
    assert_not_includes @response.body, "Beta Subject"
  end

  test "index filters by user" do
    node = logged_node("log_filter_user", "Gamma Subject")
    NodeAction.record!(:node => node, :action => "create", :user => users(:quentin))

    get :index, params: { :user_id => users(:quentin).id }
    assert_includes @response.body, "Gamma Subject"

    other = User.where.not(:id => users(:quentin).id).first
    get :index, params: { :user_id => other.id }
    assert_not_includes @response.body, "Gamma Subject"
  end

  test "index requires login" do
    session[:user_id] = nil
    @controller.instance_variable_set(:@current_user, nil)
    get :index
    assert_response :redirect
  end

  test "zooming on a node finds subtree entries recorded at its ancestor" do
    parent = Node.root.children.create!(:slug => "zoom_participant_parent")
    child  = parent.children.create!(:slug => "zoom_participant_child")
    parent.trash!(users(:quentin))

    get :index, params: { :node_id => child.id }
    assert_response :success
    assert_includes assigns(:actions).map(&:action), "trash"
  end

  test "zooming on an asset finds the publishes that changed it" do
    node  = Node.root.children.create!(:slug => "asset_zoom_node")
    asset = Asset.create!(:name => "Zoomable", :upload_content_type => "image/png")
    node.publish_draft!(users(:quentin))
    node.lock_for_editing!(users(:quentin))
    node.create_new_draft(users(:quentin))
    node.draft.related_assets.create!(:asset => asset)
    node.publish_draft!(users(:quentin))

    get :index, params: { :asset_id => asset.id }
    assert_response :success
    assert_equal 1, assigns(:actions).count
    assert_equal "publish", assigns(:actions).first.action
  end
end
