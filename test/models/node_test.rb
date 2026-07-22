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
      find_or_create_draft(test_node, @user1)
    end
    
    assert_equal 1, test_node.pages.length
  end
  
  def test_user_gets_assigned_to_unlocked_draft
    assert_not_nil @first_child.draft
    assert_nil @first_child.draft.user
    find_or_create_draft(@first_child, @user1)
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
    
    draft1 = find_or_create_draft(@first_child, @user1)
    
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
    assert_not_nil find_or_create_draft(node, @user1)
  end

  def test_find_or_create_draft_if_draft_exists_and_is_owned_by_user
    node = Node.root.children.create :slug => "xyz"
    node.publish_draft!

    first_call  = find_or_create_draft(node, @user1)
    second_call = find_or_create_draft(node, @user1)

    assert_equal first_call, second_call
    assert_equal 2, node.pages.count
    assert_equal @user1, node.lock_owner
  end

  def test_exception_if_draft_exists_but_locked_by_another_user
    node = Node.root.children.create :slug => "xyz"
    node.publish_draft!
    find_or_create_draft(node, @user1)
    assert_equal @user1, node.lock_owner
    assert_raise(LockedByAnotherUser) do
      find_or_create_draft(node, @user2)
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
    find_or_create_draft(test_node, @user1)
    test_node.reload
    assert_equal 2, test_node.pages.length
    assert_not_nil test_node.draft
    assert test_node.head != test_node.draft
  end
  
  test "restoring a revision" do
    test_node = Node.root.children.create! :slug => "test_node"
    create_revisions( test_node, 3 )
    find_or_create_draft(test_node, @user1)
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
    new_draft = find_or_create_draft(node, users(:quentin))
    assert_equal "aaron", new_draft.user.login
  end
  
  test "a new revision can overwrite the initial author" do
    Node.root.descendants.destroy_all
    node  = create_node_with_draft
    draft = node.draft
    draft.user = users(:aaron)
    draft.save!
    node.publish_draft!
    new_draft = find_or_create_draft(node, users(:quentin))
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

  test "title reads from autosave when neither draft nor head exists yet" do
    node = Node.root.children.create!(:slug => "title_autosave_only_test")
    node.draft.destroy
    node.update_column(:draft_id, nil)
    node.lock_for_editing!(users(:quentin))
    node.autosave!({ :title => "autosave-only title" }, users(:quentin))

    assert_equal "autosave-only title", node.reload.title
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
      find_or_create_draft(node, @user1)
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

  test "editor_search matches a partial substring, not just a whole word" do
    node = Node.root.children.create!(:slug => "editor_search_substring_test")
    find_or_create_draft(node, @user1)
    node.draft.update(:title => "Biometrics Conference")
    node.publish_draft!

    assert_includes Node.editor_search("bio"), node
    assert_includes Node.editor_search("Conf"), node
  end

  test "editor_search returns an empty relation for a blank term, not every node" do
    assert_equal 0, Node.editor_search("").count
    assert_equal 0, Node.editor_search(nil).count
    assert_equal 0, Node.editor_search("   ").count
  end

  test "editor_search requires every word to match, but each word can match a different field" do
    node = Node.root.children.create!(:slug => "editor_search_multiword_test")
    find_or_create_draft(node, @user1)
    node.draft.update(:title => "Backspace e.V. Bamberg", :abstract => "Spiegelgraben 41, 96052 Bamberg")
    node.publish_draft!

    assert_includes Node.editor_search("Backspace Spiegelgraben"), node
    assert_equal 0, Node.editor_search("Backspace Nonexistentstreet").count
  end

  test "drafts_and_autosaves without a user sorts by recency only" do
    older = Node.root.children.create!(:slug => "drafts_order_older")
    find_or_create_draft(older, @user1)
    newer = Node.root.children.create!(:slug => "drafts_order_newer")
    find_or_create_draft(newer, @user1)

    result = Node.drafts_and_autosaves.to_a
    assert result.index(newer) < result.index(older)
  end

  test "drafts_and_autosaves with a user puts their own locked nodes first, regardless of recency" do
    mine = Node.root.children.create!(:slug => "drafts_order_mine")
    mine.lock_for_editing!(@user1)
    mine.autosave!({:title => "mine"}, @user1)

    someone_elses_newer = Node.root.children.create!(:slug => "drafts_order_theirs")
    other_user = User.find_by_login("quentin")
    someone_elses_newer.lock_for_editing!(other_user)
    someone_elses_newer.autosave!({:title => "theirs"}, other_user)

    result = Node.drafts_and_autosaves(current_user_id: @user1.id).to_a
    assert result.index(mine) < result.index(someone_elses_newer)
  end

  test "autosave! carries over the current related assets to the newly created autosave row" do
    node = Node.root.children.create!(:slug => "autosave_asset_carryover_test")
    user = User.find_by_login("quentin")
    asset = Asset.create!(:name => "carryover-photo", :upload_content_type => "image/png")
    node.draft.assets << asset

    node.lock_for_editing!(user)
    node.autosave!({:title => "v1"}, user)

    assert_includes node.autosave.reload.assets, asset
  end

  test "autosave! does not reset assets already attached directly to an existing autosave" do
    node = Node.root.children.create!(:slug => "autosave_asset_no_reset_test")
    user = User.find_by_login("quentin")
    original = Asset.create!(:name => "original-photo", :upload_content_type => "image/png")
    extra = Asset.create!(:name => "extra-photo", :upload_content_type => "image/png")
    node.draft.assets << original

    node.lock_for_editing!(user)
    node.autosave!({:title => "v1"}, user)
    node.autosave.assets << extra

    node.autosave!({:title => "v2"}, user)

    assert_includes node.autosave.reload.assets, original
    assert_includes node.autosave.reload.assets, extra
  end

  test "autosave! carries over other-locale translations to the newly created autosave row" do
    node = Node.root.children.create!(:slug => "autosave_translation_carryover_test")
    user = User.find_by_login("quentin")

    Globalize.with_locale(:en) { node.draft.update!(:title => "English title") }

    node.lock_for_editing!(user)
    Globalize.with_locale(:de) { node.autosave!({:title => "German edit"}, user) }

    autosave = node.autosave.reload
    assert_includes autosave.translated_locales, :en
    assert_equal "English title", Globalize.with_locale(:en) { autosave.title }
    assert_equal "German edit",   Globalize.with_locale(:de) { autosave.title }
  end

  test "autosave! does not reset other-locale translations already attached directly to an existing autosave" do
    node = Node.root.children.create!(:slug => "autosave_translation_no_reset_test")
    user = User.find_by_login("quentin")

    Globalize.with_locale(:en) { node.draft.update!(:title => "Original English title") }

    node.lock_for_editing!(user)
    Globalize.with_locale(:de) { node.autosave!({:title => "v1"}, user) }
    Globalize.with_locale(:en) { node.autosave.update!(:title => "Edited directly on autosave") }

    Globalize.with_locale(:de) { node.autosave!({:title => "v2"}, user) }

    autosave = node.autosave.reload
    assert_equal "Edited directly on autosave", Globalize.with_locale(:en) { autosave.title }
    assert_equal "v2",                          Globalize.with_locale(:de) { autosave.title }
  end

  test "publish_draft! logs a NodeAction crediting the actual publisher" do
    node = Node.root.children.create!(:slug => "publish_log_test")
    node.draft.update!(:title => "Version one")

    node.publish_draft!(@user1)

    action = NodeAction.last
    assert_equal node, action.node
    assert_equal node.head, action.page
    assert_equal @user1, action.user
    assert_equal "publish", action.action
    assert_equal "draft", action.metadata["via"]
  end

  test "publish_draft! called with no user logs no actor, not a guessed one" do
    node = Node.root.children.create!(:slug => "publish_log_no_user_test")
    node.draft.update!(:title => "Version one")

    node.publish_draft!

    action = NodeAction.last
    assert_nil action.user
    assert_nil action.metadata["username"]
  end

  test "publish_draft! with nothing pending creates no NodeAction" do
    node = Node.root.children.create!(:slug => "publish_log_noop_test")
    node.publish_draft!
    count_before = NodeAction.count

    result = node.publish_draft!

    assert_nil result
    assert_equal count_before, NodeAction.count
  end

  test "revert! logs discard_autosave for an in-progress autosave" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)
    node.autosave!({:title => "in progress"}, @user1)

    node.revert!(@user1)

    action = NodeAction.last
    assert_equal node, action.node
    assert_equal @user1, action.user
    assert_equal "discard_autosave", action.action
  end

  test "revert! logs destroy_draft for a draft with a head behind it" do
    node = create_node_with_published_page
    find_or_create_draft(node, @user1)

    node.revert!(@user1)

    action = NodeAction.last
    assert_equal node, action.node
    assert_equal @user1, action.user
    assert_equal "destroy_draft", action.action
  end

  test "revert! with nothing to revert logs nothing" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)
    count_before = NodeAction.count

    node.revert!(@user1)

    assert_equal count_before, NodeAction.count
  end

  test "publish_draft! records the title diff in metadata" do
    node = create_node_with_published_page
    Globalize.with_locale(:de) { node.head.update!(:title => "Original Title") }
    find_or_create_draft(node, @user1)
    Globalize.with_locale(:de) { node.draft.update!(:title => "New Title") }

    node.publish_draft!(@user1)

    action = NodeAction.last
    assert_equal "draft",          action.metadata["via"]
    assert_equal "Original Title", action.metadata.dig("title", "from")
    assert_equal "New Title",      action.metadata.dig("title", "to")
  end

  test "publishing a staged slug change logs a move with the path pair" do
    node = create_node_with_published_page
    path_before = node.unique_name
    node.staged_slug = "moved-#{node.slug}"
    node.save!
    publish_count_before = NodeAction.where(:action => "publish").count

    node.publish_draft!(@user1)

    node.reload
    assert_not_equal path_before, node.unique_name

    action = NodeAction.where(:action => "move").last
    assert_equal node,             action.node
    assert_equal @user1,           action.user
    assert_equal path_before,      action.metadata.dig("path", "from")
    assert_equal node.unique_name, action.metadata.dig("path", "to")

    # No draft was pending: path change alone must not fabricate a publish.
    assert_equal publish_count_before, NodeAction.where(:action => "publish").count
  end

  test "publishing a draft together with a staged move logs two entries" do
    node = create_node_with_published_page
    find_or_create_draft(node, @user1)
    node.staged_slug = "relocated-#{node.slug}"
    node.save!

    assert_difference "NodeAction.count", 2 do
      node.publish_draft!(@user1)
    end

    assert_equal %w[move publish],
                 NodeAction.order(:id).last(2).map(&:action).sort
  end

  test "restore_revision! logs a publish via revision" do
    node = create_node_with_published_page
    Globalize.with_locale(:de) { node.head.update!(:title => "First") }
    first_head = node.head
    find_or_create_draft(node, @user1)
    Globalize.with_locale(:de) { node.draft.update!(:title => "Second") }
    node.publish_draft!(@user1)

    node.restore_revision!(first_head.revision, @user1)

    action = NodeAction.last
    assert_equal "publish",   action.action
    assert_equal "revision",  action.metadata["via"]
    assert_equal first_head,  action.page
    assert_equal @user1,      action.user
    assert_equal "Second",    action.metadata.dig("title", "from")
    assert_equal "First",     action.metadata.dig("title", "to")
  end

  test "default_template_name rejects values not present in the template directory" do
    node = Node.root.children.build(:slug => "template_guard_test",
                                     :default_template_name => "../../layouts/admin")
    assert_not node.valid?

    node.default_template_name = "standard_template"
    assert node.valid?
  end

  test "destroying a node with children is refused" do
    parent = Node.root.children.create!(:slug => "destroy_guard_parent")
    parent.children.create!(:slug => "destroy_guard_child")

    assert_no_difference "Node.count" do
      assert_not parent.destroy
    end
    assert parent.errors[:base].any?
  end

  test "destroying a childless node leaves no orphaned pages or asset links" do
    node = create_node_with_published_page
    page_ids = node.pages.pluck(:id)
    asset = Asset.create!(:name => "destroy cascade probe",
                          :upload_file_name    => "test_image.png",
                          :upload_content_type => "image/png",
                          :upload_file_size    => 49854,
                          :upload_updated_at   => Time.current)
    node.head.related_assets.create!(:asset_id => asset.id, :position => 1)

    node.destroy

    assert_equal 0, Page.where(:id => page_ids).count
    assert_equal 0, RelatedAsset.where(:page_id => page_ids).count
  end

  test "destroying a node also removes its autosave page" do
    node = create_node_with_published_page
    node.lock_for_editing!(@user1)
    node.autosave!({:title => "in flight"}, @user1)
    autosave_id = node.autosave_id

    node.destroy

    assert_equal 0, Page.where(:id => autosave_id).count
  end

  test "Node.trash lazily creates the container exactly once" do
    assert_difference "Node.count", 1 do
      Node.trash
    end
    assert_no_difference "Node.count" do
      assert_equal Node.trash, Node.trash
    end
    assert Node.trash.trash_node?
    assert_not Node.trash.in_trash?
    assert_equal "Trash", Globalize.with_locale(I18n.default_locale) { Node.trash.draft.title }
  end

  test "in_trash? walks the whole parent chain" do
    child = Node.trash.children.create!(:slug => "trashed_thing")
    grandchild = child.children.create!(:slug => "trashed_deeper")

    assert child.in_trash?
    assert grandchild.in_trash?
    assert_not Node.root.children.create!(:slug => "living_thing").in_trash?
  end

  test "the reserved slug is refused for other root children, live and staged" do
    Node.trash

    assert_not Node.root.children.build(:slug => CccConventions::TRASH_SLUG).valid?
    assert_not Node.root.children.build(:slug => "fine", :staged_slug => CccConventions::TRASH_SLUG).valid?
    assert Node.trash.children.create!(:slug => "sub").children.build(:slug => CccConventions::TRASH_SLUG).valid?
  end

  test "the Trash node refuses rename, move, and destroy" do
    trash = Node.trash
    other = Node.root.children.create!(:slug => "not_the_trash")

    trash.slug = "recycling"
    assert_not trash.valid?

    trash.reload.parent_id = other.id
    assert_not trash.valid?

    assert_no_difference "Node.count" do
      assert_not trash.reload.destroy
    end
  end

  test "a head cannot exist inside the Trash, and publishing there is refused" do
    node = Node.trash.children.create!(:slug => "no_publish_here")
    page = node.pages.create!

    node.head = page
    assert_not node.valid?

    node.reload
    assert_raises(ActiveRecord::RecordInvalid) { node.publish_draft! }
  end
end
