require 'test_helper'

class UsersControllerTest < ActionController::TestCase

  test "get index as regular user renders stripped partial" do
    login_as :quentin
    get :index
    assert_response :success
    assert_select "a", { :count => 0, :text => "Destroy" }
  end

  test "get index as admin shows every group with per-row actions" do
    login_as :aaron
    get :index
    assert_response :success
    assert_select "button[type=submit]", I18n.t("admin.common.destroy")
    assert_select "a", I18n.t("admin.common.show")
  end
 
  test "get new when logged in as admin" do
    login_as :aaron
    get :new
    assert_response :success
  end
 
  test "get new without being logged in as admin redirects back to index" do
    login_as :quentin
    get :new
    assert_response :redirect
    assert_redirected_to users_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:notice]
    )
  end
  
  test "creating new users being logged in as admin" do
    login_as :aaron
    assert_difference "User.count", +1 do
      post :create, params: {
        :user => {
          :login                  => "peter",
          :email                  => "foo@bar.com",
          :password               => "xxxzzz",
          :password_confirmation  => "xxxzzz"
        }
      }
    end
    
    assert_redirected_to user_path(User.last)
    assert !User.last.admin
  end
  
  test "creating new admin users being logged in as admin" do
    login_as :aaron
    assert_difference "User.count", +1 do
      post :create, params: {
        :user => {
          :login                  => "peter",
          :email                  => "foo@bar.com",
          :password               => "xxxzzz",
          :password_confirmation  => "xxxzzz",
          :roles                  => ["admin", "redaktion"]
        }
      }
    end
    
    assert_redirected_to user_path(User.last)
    assert User.last.admin
  end
  
  test "creating new users not being logged as regular user wont work" do
    login_as :quentin
    assert_no_difference "User.count" do
      post :create, params: {
        :user => {
          :login                  => "peter",
          :email                  => "foo@bar.com",
          :password               => "xxxzzz",
          :password_confirmation  => "xxxzzz"
        }
      }
    end
    
    assert_redirected_to users_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:notice]
    )
  end
  
  test "get edit of another user being logged in as regular user wont work" do
    login_as :quentin
    get :edit, params: { :id => User.find_by_login("aaron").id }
    assert_redirected_to users_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:notice]
    )
  end
  
  test "get edit of another user being logged in as admin user" do
    login_as :aaron
    get :edit, params: { :id => User.find_by_login("quentin").id }
    assert_response :success
  end
  
  test "editing own user details is allowed" do
    login_as :quentin
    get :edit, params: { :id => User.find_by_login("quentin").id }
    assert_response :success
  end
  
  test "updating an user when being logged in as regular user wont work" do
    user = User.find_by_login("aaron")
    login_as :quentin
    put :update, params: { :id => user.id, :user => {:login => "random"} }
    assert_redirected_to users_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:notice]
    )
  end
  
  test "updating an user when being login in as admin user" do
    user = User.find_by_login("quentin")
    login_as :aaron
    put :update, params: { :id => user.id, :user => {:login => "random"} }
    assert_redirected_to user_path(user)
    assert_equal "random", user.reload.login
  end
  
  test "updating own user details is allowd" do
    user = User.find_by_login("quentin")
    login_as :quentin
    put :update, params: { :id => user.id, :user => {:login => "random"} }
    assert_redirected_to user_path(user)
    assert_equal "random", user.reload.login
  end

  test "showing a user" do
    login_as :quentin
    get :show, params: { :id => User.find_by_login("aaron").id }
    assert_response :success
  end
  
  test "destroying an user being logged in as regular user wont work" do
    login_as :quentin
    assert_no_difference "User.count" do
      delete :destroy, params: { :id => User.find_by_login("aaron").id }
    end
    assert_redirected_to users_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:notice]
    )
  end
  
  test "destroying an user being logged in as admin user" do
    login_as :aaron
    assert_difference "User.count", -1 do
      delete :destroy, params: { :id => User.find_by_login("quentin").id }
    end
    assert_redirected_to users_path
  end

  test "enrolled user gets a working my account" do
    users(:quentin).update!(:otp_secret => ROTP::Base32.random)
    login_as :quentin
    get :edit, params: { :id => users(:quentin).id }
    assert_response :success
  end
  
  test "admin user can promote regular users to admins" do
    login_as :aaron
    user = users(:quentin)
    put :update, params: { :id => user.id, :user => {:roles => ["admin", "redaktion"]} }
    
    assert_equal true, user.reload.is_admin?
  end
  
  test "regular users cannot promote themselves to admins" do
    login_as :quentin
    user = users(:quentin)
    put :update, params: { :id => user.id, :user => {:roles => ["admin", "redaktion"]} }
    
    assert_equal false, user.reload.is_admin?
  end
  
  test "reset_otp is admin-only and witnessed" do
    user = users(:quentin)
    user.update!(:otp_secret => ROTP::Base32.random)

    login_as :quentin
    put :reset_otp, params: { :id => user.id }
    assert user.reload.otp_enrolled?, "non-admin must be refused"

    login_as :aaron
    put :reset_otp, params: { :id => user.id }
    assert_not user.reload.otp_enrolled?
    assert_equal "otp_reset", NodeAction.last.action
  end

  test "index groups a retired admin under alumni, not administration" do
    login_as :aaron
    user = users(:quentin)
    user.update_column(:roles, ["admin", "alumni"])

    get :index

    assert_response :success
    assert_select "h2", :text => /#{I18n.t("users.index.group_alumni")}/
  end
end
