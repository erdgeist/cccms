require 'test_helper'

class CspHeaderTest < ActionDispatch::IntegrationTest
  test "public responses carry the report-only CSP header with a nonce" do
    get "/"

    header = response.headers["Content-Security-Policy-Report-Only"]
    assert header.present?
    assert_includes header, "script-src"
    assert_includes header, "nonce-"
  end
end
