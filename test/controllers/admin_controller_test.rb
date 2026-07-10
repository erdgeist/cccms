require 'test_helper'

class AdminControllerTest < ActionController::TestCase
  test "current drafts includes nodes with only an autosave" do
    node = Node.root.children.create!(:slug => "admin_autosave_only")
    node.lock_for_editing!(User.find_by_login("aaron"))
    node.autosave!({title: "in progress"}, User.find_by_login("aaron"))
    node.save_draft!(User.find_by_login("aaron"))
    node.publish_draft!
    node.lock_for_editing!(User.find_by_login("aaron"))
    node.autosave!({title: "editing again"}, User.find_by_login("aaron"))

    login_as :quentin
    get :index
    assert_includes assigns(:drafts), node
  end

  test "my work list shows each matching node only once, even with several revisions by the same user" do
    login_as :quentin
    user = User.find_by_login("quentin")
    node = Node.root.children.create!(:slug => "dedup_test")
    node.lock_for_editing!(user)
    node.autosave!({:title => "v1"}, user)
    node.save_draft!(user)
    node.publish_draft!
    node.lock_for_editing!(user)
    node.autosave!({:title => "v2"}, user)
    node.save_draft!(user)
    node.publish_draft!
    # three pages now exist on this node, all touched by quentin --
    # without DISTINCT, the join would return this node three times

    get :index
    matches = assigns(:mynodes).select { |n| n.id == node.id }
    assert_equal 1, matches.length
  end
end
