require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase
  test "mtime_busted_path appends the file's real mtime as a query param" do
    path = "/stylesheets/admin.css"
    expected_mtime = File.mtime(Rails.public_path.join("stylesheets/admin.css")).to_i

    assert_equal "#{path}?v=#{expected_mtime}", mtime_busted_path(path)
  end

  test "mtime_busted_path raises clearly for a missing file rather than silently omitting the version" do
    assert_raises(RuntimeError) { mtime_busted_path("/stylesheets/does_not_exist.css") }
  end
end
