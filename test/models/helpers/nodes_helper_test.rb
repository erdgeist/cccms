require 'test_helper'

class NodesHelperTest < ActionView::TestCase
  FakePage = Struct.new(:tag_list)

  test "default_event_tag_mapping matches erfa-detail" do
    page = FakePage.new(["erfa-detail"])
    assert_equal ["erfa-detail", "open-day"], default_event_tag_mapping(page)
  end

  test "default_event_tag_mapping matches chaostreff-detail" do
    page = FakePage.new(["chaostreff-detail"])
    assert_equal ["chaostreff-detail", "open-day"], default_event_tag_mapping(page)
  end

  test "default_event_tag_mapping returns nil for unrelated tags" do
    page = FakePage.new(["update"])
    assert_nil default_event_tag_mapping(page)
  end

  test "default_event_tag_list is nil without a matching tag" do
    page = FakePage.new([])
    assert_nil default_event_tag_list(page)
  end
end
