require 'test_helper'

class CspReportsControllerTest < ActionController::TestCase
  test "accepts anonymous reports without CSRF" do
    post :create, body: '{"csp-report":{"violated-directive":"script-src"}}'
    assert_response :no_content
  end
end
