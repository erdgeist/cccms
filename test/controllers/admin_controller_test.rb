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

  test "dashboard_search returns matching tags and nodes grouped separately" do
    node = Node.root.children.create!(:slug => "dashboard_search_test")
    find_or_create_draft(node, User.find_by_login("aaron"))
    node.draft.update(:title => "Biometrics Workshop")
    node.draft.tag_list = "biometrics-workshop"
    node.draft.save!

    login_as :quentin
    get :dashboard_search, params: { :search_term => "biometr" }, :format => :json

    json = JSON.parse(response.body)
    assert json["tags"].any? { |t| t["name"] == "biometrics-workshop" }
    assert json["nodes"].any? { |n| n["title"] == "Biometrics Workshop" }
  end

  test "dashboard_search returns empty results for a blank term" do
    login_as :quentin
    get :dashboard_search, params: { :search_term => "" }, :format => :json

    json = JSON.parse(response.body)
    assert_equal [], json["tags"]
    assert_equal [], json["nodes"]
  end

  test "otp_required users without enrollment are funneled to setup" do
    users(:quentin).update!(:otp_required => true)
    login_as :quentin
    get :index
    assert_redirected_to edit_user_path(users(:quentin))
  end

  test "a session older than the absolute limit is rejected" do
    login_as :quentin
    @request.session[:logged_in_at] = (AuthenticatedSystem::SESSION_MAX_AGE.ago - 1.day).to_i
    get :index
    assert_response :redirect
  end

  test "a fresh session carries the login stamp" do
    login_as :quentin
    get :index
    assert_response :success
  end


  test "the dashboard reads default-locale titles under the English chrome locale" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "pin_locale_check")
    Globalize.with_locale(:de) { node.draft.update!(:title => "Deutscher Titel") }
    Globalize.with_locale(:en) { node.draft.update!(:title => "English title") }

    get :index, params: { locale: "en" }

    assert_response :success
    assert_match     "Deutscher Titel", response.body
    assert_no_match  /English title/,   response.body
  end
end
