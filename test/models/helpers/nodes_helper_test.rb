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

  test "sitemap_node_open? is false for a configured collapsed path" do
    club = Node.root.children.create!(:slug => "club")
    erfas = club.children.create!(:slug => "erfas")
    assert_equal false, sitemap_node_open?(erfas)
  end

  test "sitemap_node_open? is true for anything not configured as collapsed" do
    node = Node.root.children.create!(:slug => "sitemap_open_test")
    assert_equal true, sitemap_node_open?(node)
  end
end
