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

  test "publish renders the revision sentence, not the titles" do
    out = action_summary(entry("publish",
      { "via" => "draft", "title" => { "from" => "Old", "to" => "New" } }))

    assert_includes out, "quentin"
    assert_includes out, "new revision"
    assert_not_includes out, "Old"
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
      { "human_readable_node_name" => "<b>bold</b>" }))

    assert_not_includes out, "<b>"
  end

  test "live associations upgrade names to links" do
    out = action_summary(entry("publish",
      { "title" => { "from" => "Old", "to" => "New" } },
      :user => users(:quentin)))

    assert_includes out, "<a "
  end

  test "details are guarded off when nothing but an unchanged title is present" do
    unchanged = entry("publish", { "title" => { "from" => "Same", "to" => "Same" } })
    changed   = entry("publish", { "title" => { "from" => "Old",  "to" => "New" } })

    assert_not action_details?(unchanged)
    assert action_details?(changed)
  end

  test "first publish with a byline names the author" do
    out = action_summary(entry("publish",
      { "title" => { "from" => nil, "to" => "New" },
        "author" => { "from" => nil, "to" => "quentin" } }))

    assert_includes out, "author"
  end

  test "create entries with their flat title render and are guarded off details" do
    e = entry("create", { "title" => "Initial", "path" => "a/b" })

    assert_includes action_summary(e), "a/b"
    assert_not action_details?(e)
  end

  test "trash, restore, and destroy render their paths" do
    trash   = entry("trash",   { "path" => { "from" => "club/old", "to" => "trash/old" } })
    restore = entry("restore_from_trash", { "path" => { "from" => "trash/old", "to" => "club/new" } })
    doomed  = entry("destroy", { "path" => "trash/old" })

    assert_includes action_summary(trash),   "club/old"
    assert_includes action_summary(restore), "club/new"
    assert_includes action_summary(doomed),  "trash/old"
  end

  test "revision lifecycle badges cover create, publish, rollback, and inference" do
    created   = entry("create",  { "title" => "x", "path" => "a/b" })
    published = entry("publish", { "via" => "draft",    "title" => { "from" => nil, "to" => "x" } })
    restored  = entry("publish", { "via" => "revision", "title" => { "from" => "y", "to" => "x" } })
    restored.update!(:inferred_from => "from_page_revision")

    out = revision_lifecycle_badges([created, published, restored])

    assert_includes out, "created"
    assert_includes out, "published"
    assert_includes out, "restored"
    assert_includes out, "quentin"
    assert_includes out, "node_action_inferred"
    assert_includes out, "<span"
    assert_not_includes out, "&lt;span"

    assert_equal "", revision_lifecycle_badges(nil)
  end
end
