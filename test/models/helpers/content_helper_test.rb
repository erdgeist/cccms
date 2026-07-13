require 'test_helper'

class ContentHelperTest < ActionView::TestCase
  test "weekday_abbr delegates through the current I18n locale" do
    I18n.locale = :de
    assert_equal "Mo", weekday_abbr(Time.parse("2026-07-06"))
  end
end
