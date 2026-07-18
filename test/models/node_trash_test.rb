require "test_helper"

class NodeTrashTest < ActiveSupport::TestCase

  def setup
    @user1 = User.create!(:login => "trasher", :email => "t@example.com",
                           :password => "foobar", :password_confirmation => "foobar")
  end

  test "trash! demotes the head into the draft slot when no draft exists" do
    node = create_node_with_published_page
    former_head = node.head

    node.trash!(@user1)
    node.reload

    assert_nil node.head_id
    assert_equal former_head, node.draft
    assert node.in_trash?
  end

  test "trash! keeps an existing draft; the former head stays a plain revision" do
    node = create_node_with_published_page
    draft = find_or_create_draft(node, @user1)
    former_head = node.head

    node.trash!(@user1)
    node.reload

    assert_nil node.head_id
    assert_equal draft, node.draft
    assert_includes node.pages, former_head
  end

  test "trash! demotes descendant heads and counts them in the log entry" do
    parent = create_node_with_published_page
    child  = parent.children.create!(:slug => "trashed_child")
    child.draft.update!(:title => "Child")
    child.publish_draft!(@user1)

    parent.trash!(@user1)

    action = NodeAction.where(:action => "trash").last
    assert_equal parent, action.node
    assert_equal 2, action.metadata["demoted_heads"]
    assert action.metadata["was_published"]
    assert_nil child.reload.head_id
    assert child.in_trash?
  end

  test "trash! logs one entry with the path pair and updates unique names" do
    node = create_node_with_published_page
    path_before = node.unique_name

    assert_difference "NodeAction.count", 1 do
      node.trash!(@user1)
    end

    action = NodeAction.last
    assert_equal path_before, action.metadata.dig("path", "from")
    assert_equal node.reload.unique_name, action.metadata.dig("path", "to")
    assert action.metadata.dig("path", "to").start_with?(CccConventions::TRASH_SLUG)
  end

  test "trash! on an already trashed node is a logged-nothing no-op" do
    node = create_node_with_published_page
    node.trash!(@user1)

    assert_no_difference "NodeAction.count" do
      assert_nil node.reload.trash!(@user1)
    end
  end

  test "restore_from_trash! reparents as drafts without republishing" do
    node = create_node_with_published_page
    node.trash!(@user1)
    target = Node.root.children.create!(:slug => "restore_target")

    node.reload.restore_from_trash!(target, @user1)
    node.reload

    assert_equal target, node.parent
    assert_not node.in_trash?
    assert_nil node.head_id
    assert_not_nil node.draft_id
    assert_equal "restore_from_trash", NodeAction.last.action
  end

  test "restore_from_trash! refuses targets inside the Trash and the Trash itself" do
    node = create_node_with_published_page
    node.trash!(@user1)
    other_trashed = Node.trash.children.create!(:slug => "also_trashed")

    assert_raises(ActiveRecord::RecordInvalid) { node.reload.restore_from_trash!(Node.trash, @user1) }
    assert_raises(ActiveRecord::RecordInvalid) { node.reload.restore_from_trash!(other_trashed, @user1) }
  end

  test "destroy_from_trash! refuses nodes outside the Trash" do
    node = create_node_with_published_page

    assert_raises(ActiveRecord::RecordInvalid) { node.destroy_from_trash!(@user1) }
    assert Node.exists?(node.id)
  end

  test "destroy_from_trash! removes the whole subtree bottom-up with one entry" do
    parent = create_node_with_published_page
    child = parent.children.create!(:slug => "doomed_child")
    grandchild = child.children.create!(:slug => "doomed_grandchild")
    page_ids = [parent, child, grandchild].flat_map { |n| n.pages.pluck(:id) }
    parent.trash!(@user1)

    assert_difference "NodeAction.count", 1 do
      parent.reload.destroy_from_trash!(@user1)
    end

    assert_not Node.exists?(parent.id)
    assert_not Node.exists?(child.id)
    assert_not Node.exists?(grandchild.id)
    assert_equal 0, Page.where(:id => page_ids).count

    action = NodeAction.where(:action => "destroy").last
    assert_equal 2, action.metadata["destroyed_descendants"]
    assert_nil action.node_id
  end

  test "destroy_from_trash! logs an entry that survives the node" do
    node = create_node_with_published_page
    Globalize.with_locale(I18n.default_locale) { node.head.update!(:title => "Doomed") }
    node.trash!(@user1)
    final_path = node.reload.unique_name

    node.destroy_from_trash!(@user1)

    action = NodeAction.where(:action => "destroy").last
    assert_nil action.node_id
    assert_equal final_path, action.metadata["path"]
    assert_equal "Doomed", action.subject_name
    assert_equal @user1, action.user
  end

  test "suggested_restore_parent finds the old parent while it lives" do
    parent = Node.root.children.create!(:slug => "old_home")
    node = parent.children.create!(:slug => "comes_back")
    node.trash!(@user1)

    assert_equal parent, node.reload.suggested_restore_parent

    parent.trash!(@user1)
    assert_nil node.reload.suggested_restore_parent
  end

  test "suggested_restore_parent is root for trashed top-level nodes" do
    node = Node.root.children.create!(:slug => "was_top_level")
    node.trash!(@user1)

    assert_equal Node.root, node.reload.suggested_restore_parent
  end

  test "trashed nodes and the Trash itself stay out of the drafts surfaces" do
    Node.trash
    node = create_node_with_published_page
    node.trash!(@user1)

    ids = Node.drafts_and_autosaves.pluck(:id)
    assert_not_includes ids, Node.trash.id
    assert_not_includes ids, node.id
  end
end
