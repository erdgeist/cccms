require 'test_helper'

class NodeTest < ActiveSupport::TestCase
  
  def setup
    @root = Node.find(1)
    @first_child = Node.find(2)
    @first_child.pages.create! :title => "one"
    @first_child.draft = @first_child.pages.last
    @first_child.save
    @second_child = Node.find(3)
    @second_child.pages.create! :title => "one"
    
    @user1 = User.create :login => 'demo', :email => "f@b.com", :password => 'foobar', :password_confirmation => 'foobar'
    @user2 = User.create :login => 'show', :email => "f@b.com", :password => 'foobar', :password_confirmation => 'foobar'
  end
  
  test "can only create one root node" do
    Node.delete_all
    Node.create! :slug => :root
    assert_raise(ActiveRecord::RecordInvalid) do
      Node.create! :slug => :root
    end
  end
  
  def test_returning_existing_drafts
    test_node = Node.root.children.create! :slug => "test_node"
    
    assert_not_nil test_node.draft
    assert_equal 1, test_node.pages.length
    assert_nil test_node.draft.user
    
    3.times do 
      test_node.find_or_create_draft @user1
    end
    
    assert_equal 1, test_node.pages.length
  end
  
  def test_user_gets_assigned_to_unlocked_draft
    assert_not_nil @first_child.draft
    assert_nil @first_child.draft.user
    @first_child.find_or_create_draft @user1
    assert_equal @user1, @first_child.lock_owner
  end
  
  def test_unique_path_returns_an_array
    assert_equal ["first_child"], @first_child.unique_path
    new_node = @first_child.children.create! :slug => "third_child"
    assert_equal ["first_child", "third_child"], new_node.unique_path
  end
  
  def test_specifying_a_revision_other_than_with_a_fixnum_raises_exception
    assert_raise(ArgumentError) { Node.find_page "first_child", 1.9 }
    assert_raise(ArgumentError) { Node.find_page "first_child", "1" }
    assert_raise(ArgumentError) { Node.find_page "first_child", :head }
  end
  
  def test_publish_draft_on_a_node_without_a_draft_returns_nil
    
    assert @first_child.publish_draft!
    assert_nil @first_child.publish_draft!
  end
  
  def test_cloning_a_head_page_to_a_new_draft_with_translations
    assert_not_nil draft = @first_child.draft
    I18n.locale = :de
    draft.title = "Hallo"
    draft.abstract = "Bitte"
    draft.body = "Danke"
    draft.save
    I18n.locale = :en
    draft.title = "Hello"
    draft.abstract = "Please"
    draft.body = "Thanks"
    draft.save
    
    @first_child.publish_draft!
    
    draft1 = @first_child.find_or_create_draft(@user1)
    
    I18n.locale = :de
    assert_equal "Hallo",   draft1.title
    assert_equal "Bitte",   draft1.abstract
    assert_equal "Danke",   draft1.body
    
    I18n.locale = :en
    assert_equal "Hello",   draft1.title
    assert_equal "Please",  draft1.abstract
    assert_equal "Thanks",  draft1.body
  end
  
  def test_created_nodes_have_an_empty_draft_and_no_head
    node = Node.root.children.create! :slug => "third_child_beta"
    
    assert !node.pages.empty?
    assert_equal 1, node.pages.length
    assert_not_nil node.draft
    assert_nil node.draft.user
    assert_nil node.head
    assert_nil node.autosave
  end
  
  def test_create_new_draft_of_published_page
    node = Node.root.children.create :slug => "xyz"
    assert node.publish_draft!
  end
  
  def test_find_or_create_draft_if_no_draft_exists
    node = Node.root.children.create :slug => "xyz"
    node.publish_draft!
    assert_not_nil node.find_or_create_draft( @user1 )
  end

  def test_find_or_create_draft_if_draft_exists_and_is_owned_by_user
    node = Node.root.children.create :slug => "xyz"
    node.publish_draft!

    first_call  = node.find_or_create_draft @user1
    second_call = node.find_or_create_draft @user1

    assert_equal first_call, second_call
    assert_equal 2, node.pages.count
    assert_equal @user1, node.lock_owner
  end

  def test_exception_if_draft_exists_but_locked_by_another_user
    node = Node.root.children.create :slug => "xyz"
    node.publish_draft!
    node.find_or_create_draft @user1
    assert_equal @user1, node.lock_owner
    assert_raise(LockedByAnotherUser) do
      node.find_or_create_draft @user2
    end
  end
  
  def test_creation_of_unique_name
    node = Node.root.children.create :slug => 'child'
    node.reload
    assert_equal 'child', node.unique_name

    node = @first_child.children.create :slug => 'deep_child'
    node.reload
    assert_equal 'first_child/deep_child', node.unique_name
  end
  
  def test_order_of_pages_by_revision
    # This test should make sure the order is the same on different db's
    # Remember, there is already an empty draft
    two   = @second_child.pages.create :title => "two"
    three = @second_child.pages.create :title => "three"
    four  = @second_child.pages.create :title => "four"

    @second_child.pages.reload

    assert_equal [1,2,3,4], @second_child.pages.map { |x| x.revision }
  end
  
  def test_behavior_of_acts_as_list
    two   = @second_child.pages.create :title => "two"
    three = @second_child.pages.create :title => "three"
    four  = @second_child.pages.create :title => "four"

    assert_equal 2, two.revision
    assert_equal 3, three.revision
    assert_equal 4, four.revision

    assert_equal four, @second_child.pages.last

    assert two.move_to_bottom

    two.reload; three.reload; four.reload;

    assert_equal 4, two.revision
    assert_equal 2, three.revision
    assert_equal 3, four.revision
  end
  
  def test_retrieving_page_current
    updates = Node.root.children.create(:slug => 'updates')
    year    = updates.children.create(:slug => '2008')
    foo     = year.children.create(:slug => 'foo')

    assert_not_nil Node.find_by_unique_name('updates/2008/foo')

    # Note that there is already an initial, blank revision
    foo.pages.create :title => "Version 2"
    foo.pages.create :title => "Version 3"
    foo.pages.create :title => "Version 4"

    foo.head = foo.pages.last
    foo.save!

    page = Node.find_page("updates/2008/foo")
    assert_equal page, foo.pages.find_by_revision(4)
  end

  def test_retrieving_page_by_revision
    updates = Node.root.children.create(:slug => 'updates')
    year    = updates.children.create(:slug => '2008')
    foo     = year.children.create(:slug => 'foo')

    assert_not_nil Node.find_by_unique_name('updates/2008/foo')

    # Note that there is already an initial, blank revision
    foo.pages.create :title => "Version 2"
    foo.pages.create :title => "Version 3"
    foo.pages.create :title => "Version 4"

    page = Node.find_page("updates/2008/foo", 2)
    assert_equal "Version 2", page.title
  end
  
  # Thats a lengthy test to make sure everything works as it should, it was 
  # created during a bug hunt
  def test_creating_new_draft
    test_node = Node.root.children.create! :slug => "test_node"
    test_node.draft.user = @user1
    test_node.save
    assert test_node.publish_draft!
    test_node.reload
    assert_equal 1, test_node.pages.length
    assert_not_nil test_node.head
    assert_nil test_node.draft
    test_node.find_or_create_draft @user1
    test_node.reload
    assert_equal 2, test_node.pages.length
    assert_not_nil test_node.draft
    assert test_node.head != test_node.draft
  end
  
  test "restoring a revision" do
    test_node = Node.root.children.create! :slug => "test_node"
    create_revisions( test_node, 3 )
    test_node.find_or_create_draft @user1
    test_node.reload
    
    assert_equal 4, test_node.pages.count
    assert_equal 3, test_node.head.revision
    
    test_node.restore_revision!(1)
    assert_equal 1, test_node.head.revision
    assert_equal 4, test_node.draft.revision
  end
  
  test "a new revision keeps the initial user" do
    Node.root.descendants.destroy_all
    node  = create_node_with_draft
    draft = node.draft
    draft.user = users(:aaron)
    draft.save
    node.publish_draft!
    new_draft = node.find_or_create_draft( users(:quentin) )
    assert_equal "aaron", new_draft.user.login
  end
  
  test "a new revision can overwrite the initial author" do
    Node.root.descendants.destroy_all
    node  = create_node_with_draft
    draft = node.draft
    draft.user = users(:aaron)
    draft.save!
    node.publish_draft!
    new_draft = node.find_or_create_draft( users(:quentin) )
    new_draft.user_id = users(:quentin).id
    new_draft.save
    node.publish_draft!
    assert_equal "quentin", node.head.user.login
  end
  
  
  test "update?" do
    Node.root.descendants.delete_all
    updates       = Node.root.children.create!( :slug => "updates" )
    assert !updates.update?
    
    updates2009   = updates.children.create!( :slug => "2009" )
    assert !updates2009.update?
    
    update        = updates2009.children.create!( :slug => "my-first-update" )
    assert update.update?
  end
  
  test "new nodes should have drafts with no publidhed_at set" do
    node = Node.root.children.create( :slug => "wow" )
    assert_nil node.draft.published_at
  end

  test "lock_for_editing! acquires the lock without creating a draft or autosave" do
    node = create_node_with_published_page

    node.lock_for_editing!(@user1)

    assert_equal @user1, node.lock_owner
    assert_nil node.draft
    assert_nil node.autosave
  end

  test "autosave! creates a buffer that never appears among a node's pages, leaving the draft untouched" do
    node = create_node_with_draft
    node.lock_for_editing!(@user1)
    page_count_before = node.pages.count

    node.autosave!({ :title => "in progress" }, @user1)
    node.reload

    assert_not_nil node.autosave
    assert_nil node.autosave.node_id
    assert_equal page_count_before, node.pages.count
    assert_not_equal "in progress", node.draft.title
  end

  test "save_draft! promotes an autosave into an existing draft without creating a new revision" do
    node = create_node_with_draft
    node.lock_for_editing!(@user1)
    node.autosave!({ :title => "in progress" }, @user1)
    page_count_before = node.pages.count

    node.save_draft!(@user1)
    node.reload

    assert_nil node.autosave
    assert_equal "in progress", node.draft.title
    assert_equal page_count_before, node.pages.count
  end

  test "save_draft! promotes an autosave into a brand new, correctly-revisioned draft when none exists" do
    node = create_node_with_published_page
    head_revision = node.head.revision

    node.lock_for_editing!(@user1)
    node.autosave!({ :title => "updated version" }, @user1)
    node.reload

    assert_nil node.draft
    assert_nil node.autosave.node_id

    node.save_draft!(@user1)
    node.reload

    assert_not_nil node.draft
    assert_equal head_revision + 1, node.draft.revision
    assert_equal head_revision, node.head.revision
    assert_nil node.autosave
    assert_equal 2, node.pages.count
    assert_equal node.head.user, node.draft.user
    assert_equal @user1, node.draft.editor
    assert_equal node.head.published_at, node.draft.published_at
  end

  test "autosave!, save_draft!, and lock_for_editing! raise LockedByAnotherUser for a second user" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)

    assert_raise(LockedByAnotherUser) { node.autosave!({ :title => "x" }, @user2) }
    assert_raise(LockedByAnotherUser) { node.save_draft!(@user2) }
    assert_raise(LockedByAnotherUser) { node.lock_for_editing!(@user2) }

    assert_equal @user1, node.reload.lock_owner
  end

  test "wipe_draft! leaves a fresh autosave and its lock untouched" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)
    node.autosave!({ :title => "still typing" }, @user1)

    node.wipe_draft!
    node.reload

    assert_not_nil node.autosave
    assert_equal @user1, node.lock_owner
  end

  test "wipe_draft! destroys a stale, orphaned autosave and releases its lock" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)
    node.autosave!({ :title => "abandoned mid-session" }, @user1)
    node.autosave.update_column(:updated_at, 2.days.ago)

    node.wipe_draft!
    node.reload

    assert_nil node.autosave
    assert_nil node.lock_owner
  end

  test "revert! is a safe no-op on a fresh node with only a draft" do
    node = create_node_with_draft
    node.lock_for_editing!(@user1)

    node.revert!(@user1)
    node.reload

    assert_not_nil node.draft
    assert_equal @user1, node.lock_owner
  end

  test "revert! discards an autosave on a fresh node without touching its only draft" do
    node = create_node_with_draft
    node.lock_for_editing!(@user1)
    node.autosave!({ :title => "typing" }, @user1)

    node.revert!(@user1)
    node.reload

    assert_nil node.autosave
    assert_not_nil node.draft
    assert_equal @user1, node.lock_owner
  end

  test "revert! does nothing when a published node has no draft or autosave" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)

    node.revert!(@user1)
    node.reload

    assert_not_nil node.head
    assert_nil node.draft
  end

  test "revert! discards a fresh autosave and releases the lock when no draft exists" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)
    node.autosave!({ :title => "in progress" }, @user1)

    node.revert!(@user1)
    node.reload

    assert_nil node.autosave
    assert_nil node.draft
    assert_nil node.lock_owner
  end

  test "revert! destroys an existing draft and releases the lock" do
    node = create_node_with_published_page
    head_title = node.head.title
    node.lock_for_editing!(@user1)
    node.autosave!({ :title => "second version" }, @user1)
    node.save_draft!(@user1)

    node.revert!(@user1)
    node.reload

    assert_nil node.draft
    assert_equal head_title, node.head.title
    assert_nil node.lock_owner
  end

  test "revert! discards only the autosave when a draft survives beneath it" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)
    node.autosave!({ :title => "second version" }, @user1)
    node.save_draft!(@user1)
    node.autosave!({ :title => "third version, still typing" }, @user1)

    node.revert!(@user1)
    node.reload

    assert_nil node.autosave
    assert_not_nil node.draft
    assert_equal "second version", node.draft.title
    assert_equal @user1, node.lock_owner
  end

  test "revert! raises LockedByAnotherUser for a non-owner" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)

    assert_raise(LockedByAnotherUser) { node.revert!(@user2) }
    assert_equal @user1, node.reload.lock_owner
  end
  
  def create_revisions node, count
    count.times do
      node.find_or_create_draft @user1
      node.publish_draft!
    end
  end

  test "available_layer_pairs matches the six-state table" do
    node = Node.root.children.create!(:slug => "layer_pairs_test")
    user = @user1 || User.find_by_login("aaron")

    assert_equal [[:draft, :autosave]], (node.lock_for_editing!(user); node.autosave!({title: "v1"}, user); node.available_layer_pairs) # state F

    node.save_draft!(user)
    node.publish_draft!
    assert_equal [], node.available_layer_pairs # state A

    node.lock_for_editing!(user)
    node.autosave!({title: "v2"}, user)
    assert_equal [[:head, :autosave]], node.available_layer_pairs # state B

    node.save_draft!(user)
    assert_equal [[:head, :draft]], node.available_layer_pairs # state C

    node.lock_for_editing!(user)
    node.autosave!({title: "v3"}, user)
    assert_equal [[:head, :draft], [:draft, :autosave]], node.available_layer_pairs # state D
  end

  test "publishing a staged move under one's own descendant is rejected, not allowed to crash" do
    a = Node.root.children.create!(:slug => "cycle_guard_a")
    b = a.children.create!(:slug => "cycle_guard_b")

    a.staged_parent_id = b.id

    assert_raises(ActiveRecord::RecordInvalid) { a.publish_draft! }

    a.reload
    assert_equal Node.root.id, a.parent_id
  end
end
