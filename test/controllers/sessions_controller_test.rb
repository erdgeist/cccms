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
end
