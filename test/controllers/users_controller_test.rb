require 'test_helper'

class UsersControllerTest < ActionController::TestCase

  test "an editor without admin cannot reach the user list" do
    login_as :quentin
    get :index
    assert_redirected_to admin_path
    assert_equal I18n.t("flash.common.redaktion_required"), flash[:error]
  end

  test "get index as admin shows every group with per-row actions" do
    login_as :aaron
    get :index
    assert_response :success
    assert_select "button[type=submit][aria-label=?]", I18n.t("users.user.deactivate")
    assert_select "a[aria-label=?]", I18n.t("admin.common.show")
  end
 
  test "get new when logged in as admin" do
    login_as :aaron
    elevate_session!
    get :new
    assert_response :success
  end
 
  test "get new without being logged in as admin redirects back to index" do
    login_as :quentin
    get :new
    assert_response :redirect
    assert_redirected_to admin_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:error]
    )
  end
  
  test "creating new users being logged in as admin" do
    login_as :aaron
    elevate_session!
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
  
  test "creating a Redaktion account" do
    login_as :aaron
    elevate_session!
    assert_difference "User.count", +1 do
      post :create, params: {
        :user => {
          :login                  => "peter",
          :email                  => "foo@bar.com",
          :password               => "xxxzzz",
          :password_confirmation  => "xxxzzz",
          :roles                  => ["redaktion"]
        }
      }
    end
    
    assert_redirected_to user_path(User.last)
    assert User.last.redaktion?
    assert_not User.last.is_admin?
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
    
    assert_redirected_to admin_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:error]
    )
  end
  
  test "get edit of another user being logged in as regular user wont work" do
    login_as :quentin
    get :edit, params: { :id => User.find_by_login("aaron").id }
    assert_redirected_to admin_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:error]
    )
  end
  
  test "get edit of another user being logged in as admin user" do
    login_as :aaron
    elevate_session!
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
    assert_redirected_to admin_path
    assert_equal(
      I18n.t("flash.common.admin_required"),
      flash[:error]
    )
  end
  
  test "updating an user when being login in as admin user" do
    user = User.find_by_login("quentin")
    login_as :aaron
    elevate_session!
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
    get :show, params: { :id => users(:quentin).id }
    assert_response :success
  end
  
  test "destroying an user being logged in as regular user wont work" do
    login_as :quentin
    put :deactivate, params: { :id => users(:quentin).id }

    assert_redirected_to admin_path
    assert_not users(:quentin).reload.alumni?
  end
  
  test "an admin deactivates another user, who can no longer sign in" do
    login_as :aaron
    elevate_session!
    user = users(:quentin)

    put :deactivate, params: { :id => user.id }

    assert_redirected_to users_path
    assert user.reload.alumni?
    assert_equal ["admin", "alumni"].sort, user.roles.sort if user.is_admin?
  end

  test "reactivation restores the other roles untouched" do
    login_as :aaron
    elevate_session!
    user = users(:quentin)
    user.update_column(:roles, ["alumni", "redaktion"])

    put :reactivate, params: { :id => user.id }

    assert_not user.reload.alumni?
    assert_equal ["redaktion"], user.roles
  end

  test "an admin cannot deactivate their own account" do
    login_as :aaron
    put :deactivate, params: { :id => users(:aaron).id }
    assert_not users(:aaron).reload.alumni?
  end

  test "enrolled user gets a working my account" do
    users(:quentin).update!(:otp_secret => ROTP::Base32.random)
    login_as :quentin
    get :edit, params: { :id => users(:quentin).id }
    assert_response :success
  end
  
  test "admin user can promote regular users to admins" do
    login_as :aaron
    elevate_session!
    user = users(:quentin)
    user.update_column(:otp_secret, ROTP::Base32.random)
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
    elevate_session!
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

  test "an editor without admin cannot create accounts" do
    login_as :quentin
    get :new
    assert_redirected_to admin_path
  end

  test "an editor cannot read another account by id" do
    login_as :quentin
    get :show, params: { :id => users(:aaron).id }
    assert_redirected_to admin_path
  end

  test "an admin without an open window is sent to elevation" do
    login_as :aaron
    get :new
    assert_redirected_to new_elevation_path
  end

  test "an unelevated admin cannot change roles" do
    login_as :aaron
    user = users(:quentin)

    put :update, params: { :id => user.id, :user => { :roles => ["admin"] } }

    assert_not user.reload.is_admin?
  end

  test "an account without a second factor cannot be promoted to admin" do
    login_as :aaron
    elevate_session!
    user = users(:quentin)

    put :update, params: { :id => user.id, :user => { :roles => ["admin"] } }

    assert_not user.reload.is_admin?
  end

  test "clearing the factor closes an open elevation window" do
    login_as :aaron
    elevate_session!
    get :new, params: { :locale => "de" }
    assert_response :success

    users(:aaron).update_column(:otp_secret, nil)

    get :new, params: { :locale => "de" }
    assert_redirected_to new_elevation_path
  end

  test "creating a user is witnessed" do
    login_as :aaron
    elevate_session!

    assert_difference -> { NodeAction.where(:action => "user_create").count }, 1 do
      post :create, params: { :locale => "de", :user => {
        :login => "newcomer", :email => "n@example.org",
        :password => "secret123", :password_confirmation => "secret123" } }
    end

    entry = NodeAction.where(:action => "user_create").last
    assert_equal users(:aaron).id, entry.user_id
    assert_equal "newcomer", entry.metadata["target_login"]
    assert_equal User.find_by(:login => "newcomer").id,
                 entry.action_participants.first.subject_id
  end

  test "editing another account without elevation prompts for a code" do
    login_as :aaron
    get :edit, params: { :locale => "de", :id => users(:quentin).id }
    assert_redirected_to new_elevation_path
  end

  test "editing your own account needs no elevation" do
    login_as :aaron
    get :edit, params: { :locale => "de", :id => users(:aaron).id }
    assert_response :success
  end

  test "a role change submitted without elevation is refused, not silently dropped" do
    login_as :aaron
    target = users(:quentin)
    assert_empty target.roles

    put :update, params: { :locale => "de", :id => target.id,
                           :user => { :roles => ["", "redaktion"] } }

    assert_redirected_to new_elevation_path
    assert_empty target.reload.roles
    assert_nil flash[:notice]
  end

  test "a role change with elevation goes through" do
    login_as :aaron
    elevate_session!
    target = users(:redella)
    target.update_column(:otp_secret, ROTP::Base32.random)

    put :update, params: { :locale => "de", :id => target.id,
                           :user => { :roles => ["", "redaktion", "admin"] } }

    assert_redirected_to user_path(target)
    assert_equal ["admin", "redaktion"], target.reload.roles.sort
  end

  test "editing your own account without elevation does not prompt" do
    login_as :aaron
    put :update, params: { :locale => "de", :id => users(:aaron).id,
                           :user => { :roles => ["", "admin", "redaktion"] } }
    assert_redirected_to user_path(users(:aaron))
  end

  test "changing your own roles without elevation is refused" do
    login_as :aaron
    put :update, params: { :locale => "de", :id => users(:aaron).id,
                           :user => { :roles => [""] } }
    assert_redirected_to new_elevation_path
    assert_equal ["admin", "redaktion"], users(:aaron).reload.roles.sort
  end
end
