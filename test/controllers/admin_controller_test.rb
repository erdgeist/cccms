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
end
