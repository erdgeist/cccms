require 'test_helper'

class EventsHelperTest < ActionView::TestCase
  test "rrule_with_break_opportunities inserts a break opportunity after each semicolon" do
    result = rrule_with_break_opportunities("FREQ=MONTHLY;BYMONTH=1,2,3;BYDAY=-1TH")
    assert_equal "FREQ=MONTHLY;<wbr>BYMONTH=1,2,3;<wbr>BYDAY=-1TH", result
    assert result.html_safe?
  end

  test "rrule_with_break_opportunities escapes HTML-significant characters" do
    result = rrule_with_break_opportunities("FREQ=WEEKLY;BYDAY=<script>")
    assert_no_match /<script>/, result
    assert_match "&lt;script&gt;", result
  end

  test "rrule_with_break_opportunities returns an empty string for blank input" do
    assert_equal "", rrule_with_break_opportunities(nil)
    assert_equal "", rrule_with_break_opportunities("")
  end

  test "rrule_with_break_opportunities preserves a trailing semicolon" do
    result = rrule_with_break_opportunities("FREQ=WEEKLY;")
    assert_equal "FREQ=WEEKLY;<wbr>", result
  end
end
