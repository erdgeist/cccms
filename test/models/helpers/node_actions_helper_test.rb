require 'test_helper'

class NodeActionsHelperTest < ActionView::TestCase
  def setup
    @original_locale = I18n.locale
    I18n.locale = :en
  end

  def default_url_options
    { :locale => nil }
  end

  def teardown
    I18n.locale = @original_locale
  end

  def entry action, metadata = {}, node: nil, user: nil, page: nil
    NodeAction.create!(:node => node, :user => user, :page => page,
                        :action => action, :occurred_at => Time.now,
                        :metadata => { "username" => "quentin",
                                       "human_readable_node_name" => "Subject" }.merge(metadata))
  end

  test "publish renders the title pair" do
    out = action_summary(entry("publish",
      { "via" => "draft", "title" => { "from" => "Old", "to" => "New" } }))

    assert_includes out, "quentin"
    assert_includes out, "Old"
  end

  test "first publish uses its own sentence" do
    out = action_summary(entry("publish",
      { "via" => "draft", "title" => { "from" => nil, "to" => "New" } }))

    assert_includes out, "for the first time"
  end

  test "rollback publishes get the rollback sentence" do
    out = action_summary(entry("publish",
      { "via" => "revision", "title" => { "from" => "Now", "to" => "Then" } }))

    assert_includes out, "rolled"
  end

  test "move renders the path pair" do
    out = action_summary(entry("move",
      { "path" => { "from" => "a/b", "to" => "a/c" } }))

    assert_includes out, "a/b"
    assert_includes out, "a/c"
  end

  test "unknown verbs degrade to a generic sentence, never an error" do
    out = action_summary(entry("frobnicate"))

    assert_includes out, "frobnicate"
    assert_includes out, "quentin"
  end

  test "dead references render as plain names from metadata, no links" do
    out = action_summary(entry("publish",
      { "title" => { "from" => "Old", "to" => "New" } }))

    assert_not_includes out, "<a "
    assert_includes out, "Subject"
  end

  test "metadata values are escaped" do
    out = action_summary(entry("publish",
      { "human_readable_node_name" => "<b>bold</b>",
        "title" => { "from" => "<script>alert(1)</script>", "to" => "x" } }))

    assert_not_includes out, "<script>"
    assert_not_includes out, "<b>"
  end

  test "live associations upgrade names to links" do
    out = action_summary(entry("publish",
      { "title" => { "from" => "Old", "to" => "New" } },
      :user => users(:quentin)))

    assert_includes out, "<a "
  end
end
