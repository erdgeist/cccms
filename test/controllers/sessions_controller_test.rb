require File.dirname(__FILE__) + '/../test_helper'

class SessionsControllerTest < ActionController::TestCase
  include AuthenticatedTestHelper

  fixtures :users

  def test_should_login_and_redirect
    post :create, params: { login: 'quentin', password: 'monkey' }
    assert session[:user_id]
    assert_response :redirect
  end

  def test_should_fail_login_and_not_redirect
    post :create, params: { login: 'quentin', password: 'bad password' }
    assert_nil session[:user_id]
    assert_response :success
  end

  def test_should_logout
    login_as :quentin
    get :destroy
    assert_nil session[:user_id]
    assert_response :redirect
  end

  test "login with password only is withheld for enrolled users" do
    users(:quentin).update!(:otp_secret => ROTP::Base32.random)
    post :create, params: { login: 'quentin', password: 'monkey' }
    assert_nil session[:user_id]
    assert_equal users(:quentin).id, session[:pending_otp_user_id]
    assert_redirected_to new_otp_challenge_path
  end

  test "otp_required without enrollment logs in but funnels into setup" do
    users(:quentin).update!(:otp_required => true)
    post :create, params: { login: 'quentin', password: 'monkey' }
    assert session[:user_id]
    assert_redirected_to edit_user_path(users(:quentin))
  end
end
