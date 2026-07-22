require 'test_helper'

class NodesControllerTest < ActionController::TestCase

  def test_get_index
    Node.root.descendants.delete_all
    test_node = Node.root.children.create :slug => "foo"
    login_as :quentin
    get :index
    assert_response :success
  end

  def test_new
    login_as :quentin
    get :new
    assert_response :success
  end

  test "create generic node with parent_id provided" do
    login_as :quentin
    before_count = Node.count
    post(
      :create,
      params: {
        :kind => "generic",
        :parent_id => Node.root.id,
        :title => "Hello Spaceboy"
      }
    )
    assert_response :redirect
    assert_equal before_count + 1, Node.count
    assert_equal "hello-spaceboy", Node.last.slug
    assert_equal Node.last.parent_id, Node.root.id
    assert_equal 1, Node.last.level
  end

  test "create update node" do
    login_as :quentin
    post(
      :create,
      params: {
        :kind => "update",
        :title => "Hello Spaceboy"
      }
    )
    assert_response :redirect
  end

  test "create top level node" do
    login_as :quentin
    before_count = Node.count
    post(
      :create,
      params: {
        :kind => "top_level",
        :title => "Hello My Spaceboy"
      }
    )
    assert_response :redirect
    assert_equal before_count + 1, Node.count
    expected = "hello-my-spaceboy"
    assert_equal expected, Node.last.unique_name
    assert_equal 1, Node.last.level
  end

  test "creating a top_level node without a title should not work" do
    login_as :quentin

    assert_no_difference "Node.count" do
      post(:create, params: { :kind => "top_level" } )
    end
  end

  test "creating a generic node without a parent_id should not work" do
    login_as :quentin

    assert_no_difference "Node.count" do
      post(:create, params: { :kind => "generic" } )
    end
  end

  test "editing a node" do
    login_as :quentin

    node = Node.find_by_unique_name("fourth_child")
    node.pages.create
    node.draft = node.pages.last
    node.save

    assert_equal 1, node.pages.length

    draft = find_or_create_draft(node, User.first)
    draft.title = "Hello"
    draft.body = "World"
    draft.save
    node.publish_draft!

    get :edit, params: { :id => node.id }
    assert_response :success
    assert_select("#page_title[value='Hello']")
    assert_select("#page_body", "World")

    node.reload
    assert_equal 1, node.pages.length
    assert_equal "Hello", find_or_create_draft(node, User.first).title
    assert_equal "World", find_or_create_draft(node, User.first).body
  end

  test "editing a locked node raises LockedByAnotherUser Exception" do
    login_as :quentin

    node = create_node_with_draft
    node.lock_owner = User.last
    node.save

    assert node.locked?

    get :edit, params: { :id => node.id }
    assert_response :redirect
    assert flash[:error] =~ /Page is locked by another user/
  end

  def test_update_a_draft
    test_node = Node.root.children.create! :slug => "test_node"
    login_as :quentin
    get :edit, params: { :id => test_node.id }
    put :update, params: { :id => test_node.id, :page => {:title => "Hello", :body => "There"} }
    test_node.reload
    assert_equal "Hello", test_node.draft.title
    assert_equal "There", test_node.draft.body
  end

  def test_update_a_draft_with_changing_the_template
    test_node = Node.root.children.create! :slug => "test_node"

    login_as :quentin
    get :edit, params: { :id => test_node.id }
    put :update, params: {
      :id => test_node.id,
      :page => {
        :title => "Hello",
        :body => "There",
        :template_name => "title_only"
      }
    }

    put :publish, params: { :id => test_node.id }
    test_node.reload
    assert_equal "Hello", test_node.head.title
    assert_equal "There", test_node.head.body
    assert_equal "title_only", test_node.head.template_name
  end

  def test_update_rejects_a_template_name_not_on_disk
    test_node = Node.root.children.create! :slug => "test_node"
    login_as :quentin
    put :update, params: { :id => test_node.id,
                           :page => { :title => "Hello", :template_name => "Foobar" } }

    test_node.reload
    assert_not_equal "Foobar", test_node.draft&.template_name
  end

  test "publish draft with staged_slug unqueal slug" do
    login_as :quentin

    test_node = Node.root.children.create! :slug => "test_node", :staged_slug => "peter_pan"

    put :publish, params: { :id => test_node.id }

    test_node.reload
    assert_equal "peter_pan", test_node.slug
    assert_equal "peter_pan", test_node.unique_name
  end

  test "publish draft with staged_slug with more levels of nodes" do
    login_as :quentin

    test_node = Node.root.children.create! :slug => "test_node", :staged_slug => "peter_pan"
    test_node2 = test_node.children.create! :slug => "test_node2"

    put :publish, params: { :id => test_node.id }

    test_node.reload; test_node2.reload
    assert_equal "peter_pan/test_node2", test_node2.unique_name
    assert_equal "peter_pan", test_node.unique_name
  end

  test "publish draft with staged_parent_id" do
    login_as :quentin

    parent = Node.root.children.create! :slug => "parent"
    test_node = Node.root.children.create! :slug => "test_node", :staged_parent_id => parent.id
    test_node2 = test_node.children.create! :slug => "test_node2"

    put :publish, params: { :id => test_node.id }

    test_node.reload; test_node2.reload
    assert_equal "parent/test_node", test_node.unique_name
    assert_equal "parent/test_node/test_node2", test_node2.unique_name
  end

  test "publish draft with staged_parent_id and staged_slug" do
    login_as :quentin

    parent = Node.root.children.create! :slug => "parent"

    test_node = Node.root.children.create!(
      :slug => "test_node",
      :staged_parent_id => parent.id,
      :staged_slug => "peter_pan"
    )

    test_node2 = test_node.children.create! :slug => "test_node2"

    put :publish, params: { :id => test_node.id }

    test_node.reload; test_node2.reload
    assert_equal "parent/peter_pan", test_node.unique_name
    assert_equal "parent/peter_pan/test_node2", test_node2.unique_name
  end

  test "show node with empty draft" do
    login_as :quentin
    assert_not_nil node = create_node_with_draft
    get :show, params: { :id => node.id }
    assert_response :success
  end

  test "show node with published draft" do
    login_as :quentin
    node = create_node_with_published_page
    get :show, params: { :id => node.id }
    assert_response :success
    assert_select "div.node_content", :text => "Test", :count => 2
  end

  test "unlocking a locked node" do
    login_as :quentin
    node = create_node_with_published_page
    find_or_create_draft(node, User.first)

    assert node.locked?

    put :unlock, params: { :id => node.id }
    assert_response :redirect
    assert !node.reload.locked?
  end

  test "unlocking an already unlocked node" do
    login_as :quentin
    node = create_node_with_published_page

    put :unlock, params: { :id => node.id }
    assert_response :redirect
    assert_equal "Already unlocked", flash[:notice]
  end

  test "updating a node by changing its parent" do
    Node.root.descendants.destroy_all
    login_as :quentin
    node = create_node_with_published_page
    find_or_create_draft(node, User.first)

    other_node = Node.root.children.create( :slug => "other" )

    node.staged_parent_id = other_node.id
    node.publish_draft!

    assert Node.valid?
  end

  test "editing the initial draft sets the author to current_user" do
    login_as :quentin
    Node.root.descendants.destroy_all
    node = create_node_with_draft
    get :edit, params: { :id => node.id }
    node.reload
    assert_equal "quentin", node.draft.user.login
  end

  test "updating the author of a node with existing head" do
    login_as :quentin
    Node.root.descendants.destroy_all
    node  = create_node_with_published_page
    assert_equal "quentin", node.head.user.login
    find_or_create_draft(node, users(:quentin))
    assert node.draft.valid?
    assert node.valid?

    put :update, params: { :id => node.id, :page => {:user_id => users(:aaron).id} }
    assert_response :redirect
    assert_equal "aaron", node.reload.draft.user.login
  end

  test "updating an existing page should not modify published_at" do
    login_as :quentin
    Node.root.descendants.destroy_all
    node  = create_node_with_published_page

    get :edit, params: { :id => node.id }
    assert_response :success

    put :update,  params: { :id => node.id, :page => { :title => "updated" } }
    put :publish, params: { :id => node.id }

    node.reload
    assert_equal node.pages[0].published_at, node.pages[1].published_at
  end

  test "updating an exisiting page should not alter the author" do
    login_as :aaron
    Node.root.descendants.destroy_all
    node  = create_node_with_published_page
    get :edit,    params: { :id => node.id }

    put :update,  params: { :id => node.id, :page => { :title => "updated" } }
    put :publish, params: { :id => node.id }

    node.reload
    assert_equal node.pages[0].user, node.pages[1].user
  end

  test "editor and author are the same on a new node" do
    login_as :quentin
    node = create_node_with_draft
    get :edit, params: { :id => node.id }

    node.reload
    assert_equal "quentin", node.draft.user.login
    assert_equal "quentin", node.draft.editor.login
  end

  test "creating new draft alters the editor but keeps the author" do
    node = create_node_with_published_page
    assert_equal "quentin", node.head.user.login

    login_as :aaron
    get :edit,   params: { :id => node.id }
    put :update, params: { :id => node.id, :page => { :title => "updated" } }

    node.reload
    assert_equal "quentin", node.head.user.login
    assert_equal "aaron",   node.draft.editor.login
  end

  test "unlocking and relocking changes editor if done by another user" do
    node  = create_node_with_published_page
    draft = find_or_create_draft(node, users(:quentin))
    assert_equal draft.user.login, draft.editor.login
    assert node.locked?
    node.unlock!

    login_as :aaron
    get :edit, params: { :id => node.id }

    node.reload
    assert_equal "quentin", node.draft.user.login
    assert_equal "aaron", node.draft.editor.login
  end

  test "destroy a published node" do
    node = create_node_with_published_page
    node.destroy

    login_as :quentin
    get :index
    assert_response :success
  end

  test "no dangling pages remain after node removal" do
    node = create_node_with_published_page
    page_id = node.pages.first.id
    node.destroy

    assert_raises(ActiveRecord::RecordNotFound) do
      assert Page.find page_id
    end
  end

  test "can remove a node with an event" do
    node = create_node_with_published_page
    event = Event.create!(
      :start_time   => "2009-01-01T15:23:42".to_time,
      :end_time     => "2009-01-01T20:05:23".to_time,
      :url          => "http://events.ccc.de/congress/2082",
      :latitude     => 52.525308,
      :longitude    => 13.378944,
      :allday       => true,
      :node_id      => node.id
    )
    event_id = event.id
    assert_operator Occurrence.where(event_id: event_id).count, :>, 0, "expected the event to have generated at least one occurrence before destroy"

    node.destroy

    assert_equal 0, Occurrence.where(event_id: event_id).count

    login_as :quentin
    get :index
    assert_response :success
  end

  test "show renders events row and add-link for zero-event chapter node" do
    login_as :quentin
    node = create_node_with_published_page
    node.head.tag_list = "erfa-detail"
    node.head.save!

    get :show, params: { id: node.id }
    assert_response :success
    assert_select "a", text: "Add event"
    assert_select "a[href*='tag_list=open-day']"
    assert_select "a[href*='auto_tag_source=erfa-detail']"
  end

  test "show renders events row without a tag default for untagged node" do
    login_as :quentin
    node = create_node_with_published_page

    get :show, params: { id: node.id }
    assert_response :success
    assert_select "a", text: "Add event"
    assert_select "a[href*='tag_list=']", count: 0
  end

  test "show never renders a destroy link for events" do
    login_as :quentin
    node = create_node_with_published_page
    event = Event.create!(node_id: node.id, start_time: Time.now, end_time: Time.now + 1.hour)

    get :show, params: { id: node.id }
    assert_response :success
    assert_select "form[action=?]", event_path(event), count: 0
  end

  test "reverting from nodes#show returns to the show page, not the editor, even if a draft remains" do
    user = User.find_by_login("aaron")
    node = Node.root.children.create!(:slug => "revert_return_to_test")
    node.lock_for_editing!(user)
    node.autosave!({:title => "v1"}, user)
    node.save_draft!(user)
    node.publish_draft!
    node.lock_for_editing!(user)
    node.autosave!({:title => "v2"}, user)
    node.save_draft!(user)
    node.lock_for_editing!(user)
    node.autosave!({:title => "v3"}, user)
    # state D: head, draft, and autosave all present, locked by aaron

    login_as :aaron
    put :revert, params: { :id => node.id, :return_to => node_path(node) }
    assert_redirected_to node_path(node)
    node.reload
    assert node.draft.present?
    assert node.autosave.blank?
  end

  test "reverting from nodes#edit without return_to still lands back in the editor when a draft remains" do
    user = User.find_by_login("aaron")
    node = Node.root.children.create!(:slug => "revert_default_test")
    node.lock_for_editing!(user)
    node.autosave!({:title => "v1"}, user)
    node.save_draft!(user)
    node.publish_draft!
    node.lock_for_editing!(user)
    node.autosave!({:title => "v2"}, user)
    node.save_draft!(user)
    node.lock_for_editing!(user)
    node.autosave!({:title => "v3"}, user)

    login_as :aaron
    put :revert, params: { :id => node.id }
    assert_redirected_to edit_node_path(node)
  end

  test "nodes#show does not offer to destroy the only draft of a never-published node" do
    node = Node.root.children.create!(:slug => "draft_only_test")
    login_as :quentin
    get :show, params: { :id => node.id }
    assert_response :success
    assert_select "form[action=?]", revert_node_path(node), count: 0
    assert_select "form[action=?]", trash_node_path(node), count: 1
  end

  test "drafts includes a never-published node with only a draft" do
    node = Node.root.children.create!(:slug => "drafts_action_test")
    login_as :quentin
    get :drafts
    assert_includes assigns(:nodes), node
  end

  test "chapters filters by kind, matching head or draft, and shows both by default" do
    erfa_node = Node.root.children.create!(:slug => "chapters_erfa_test")
    find_or_create_draft(erfa_node, @user1)
    erfa_node.draft.tag_list = "erfa-detail"
    erfa_node.draft.save!
    erfa_node.publish_draft!

    chaostreff_node = Node.root.children.create!(:slug => "chapters_chaostreff_test")
    find_or_create_draft(chaostreff_node, @user1)
    chaostreff_node.draft.tag_list = "chaostreff-detail"
    chaostreff_node.draft.save!
    chaostreff_node.publish_draft!

    login_as :quentin

    get :chapters, params: { :kinds => "erfa" }
    assert_includes assigns(:nodes), erfa_node
    assert_not_includes assigns(:nodes), chaostreff_node

    get :chapters
    assert_includes assigns(:nodes), erfa_node
    assert_includes assigns(:nodes), chaostreff_node
  end

  test "drafts combined with a search term does not raise an ambiguous column error" do
    login_as :quentin
    get :drafts, params: { :q => "Zombies" }
    assert_response :success
  end

  test "mine combined with a search term does not raise an ambiguous column error" do
    login_as :quentin
    get :mine, params: { :q => "Zombies" }
    assert_response :success
  end

  test "mine shows each matching node only once, even with several revisions by the same user" do
    login_as :quentin
    user = User.find_by_login("quentin")
    node = Node.root.children.create!(:slug => "dedup_test")
    node.lock_for_editing!(user)
    node.autosave!({:title => "v1"}, user)
    node.save_draft!(user)
    node.publish_draft!
    node.lock_for_editing!(user)
    node.autosave!({:title => "v2"}, user)
    node.save_draft!(user)
    node.publish_draft!
    # three pages now exist on this node, all touched by quentin --
    # without DISTINCT, the join would return this node three times

    get :mine
    matches = assigns(:nodes).select { |n| n.id == node.id }
    assert_equal 1, matches.length
  end

  test "chapters combined with a search term does not raise an ambiguous column error" do
    login_as :quentin
    get :chapters, params: { :q => "Zombies" }
    assert_response :success
  end

  test "tags path filters by an arbitrary raw tag, generalizing chapters" do
    presse_node = Node.root.children.create!(:slug => "tags_path_presse_test")
    find_or_create_draft(presse_node, @user1)
    presse_node.draft.tag_list = "pressemitteilung"
    presse_node.draft.save!
    presse_node.publish_draft!

    erfa_node = Node.root.children.create!(:slug => "tags_path_erfa_test")
    find_or_create_draft(erfa_node, @user1)
    erfa_node.draft.tag_list = "erfa-detail"
    erfa_node.draft.save!
    erfa_node.publish_draft!

    login_as :quentin
    get :tags, params: { :tags => "pressemitteilung" }

    assert_includes assigns(:nodes), presse_node
    assert_not_includes assigns(:nodes), erfa_node

    assert_select "h1", "Nodes tagged: pressemitteilung"
    assert_select "h1", :text => "Chapters", :count => 0
  end

  test "tags path with multiple tags matches any of them, not all" do
    erfa_node = Node.root.children.create!(:slug => "tags_path_multi_erfa_test")
    find_or_create_draft(erfa_node, @user1)
    erfa_node.draft.tag_list = "erfa-detail"
    erfa_node.draft.save!
    erfa_node.publish_draft!

    chaostreff_node = Node.root.children.create!(:slug => "tags_path_multi_chaostreff_test")
    find_or_create_draft(chaostreff_node, @user1)
    chaostreff_node.draft.tag_list = "chaostreff-detail"
    chaostreff_node.draft.save!
    chaostreff_node.publish_draft!

    login_as :quentin
    get :tags, params: {:tags => "erfa-detail,chaostreff-detail" }

    assert_includes assigns(:nodes), erfa_node
    assert_includes assigns(:nodes), chaostreff_node
  end

  test "chapters renders the curated heading" do
    login_as :quentin
    get :chapters
    assert_select "h1", "Chapters"
  end

  test "sitemap collapses configured paths but leaves others open" do
    club = Node.root.children.create!(:slug => "club")
    erfas = club.children.create!(:slug => "erfas")
    erfas.children.create!(:slug => "one_chapter")
    other = Node.root.children.create!(:slug => "sitemap_controller_open_test")
    other.children.create!(:slug => "sitemap_controller_open_child")

    login_as :quentin
    get :sitemap
    assert_response :success

    doc = Nokogiri::HTML::DocumentFragment.parse(response.body)

    erfas_node_div = doc.css('.sitemap_node').find { |div| div.at_css('.field_hint')&.text&.include?(erfas.unique_name) }
    other_node_div = doc.css('.sitemap_node').find { |div| div.at_css('.field_hint')&.text&.include?(other.unique_name) }

    erfas_details = erfas_node_div.next_element
    other_details = other_node_div.next_element

    assert_equal 'details', erfas_details.name
    assert_equal 'details', other_details.name
    assert_not erfas_details.key?('open')
    assert other_details.key?('open')
  end

  test "sitemap shows how many descendants a collapsed branch is hiding" do
    club = Node.root.children.create!(:slug => "club")
    erfas = club.children.create!(:slug => "erfas")
    erfas.children.create!(:slug => "one_chapter")
    erfas.children.create!(:slug => "another_chapter")

    login_as :quentin
    get :sitemap
    assert_response :success

    doc = Nokogiri::HTML::DocumentFragment.parse(response.body)
    erfas_node_div = doc.css('.sitemap_node').find { |div| div.at_css('.field_hint')&.text&.include?(erfas.unique_name) }
    erfas_details = erfas_node_div.next_element

    assert_equal 'details', erfas_details.name
    assert_match "2 descendants", erfas_details.at_css('summary').text
  end

  test "sitemap shows Show and Create Child, not Revisions" do
    node = Node.root.children.create!(:slug => "sitemap_actions_test")
    login_as :quentin
    get :sitemap
    assert_select ".sitemap_node_actions", :text => /Show/
    assert_select ".sitemap_node_actions", :text => /Create Child/
    assert_select ".sitemap_node_actions", :text => /Revisions/, :count => 0
  end

  test "create logs a create NodeAction with path and title" do
    login_as :quentin

    assert_difference "NodeAction.count" do
      post :create, params: { :kind => "generic", :title => "Brand New", :parent_id => Node.root.id }
    end

    action = NodeAction.last
    assert_equal "create",               action.action
    assert_equal users(:quentin),        action.user
    assert_equal Node.last,              action.node
    assert_equal "Brand New",            action.metadata["title"]
    assert_equal Node.last.unique_name,  action.metadata["path"]
  end

  test "trash moves the node and redirects to the Trash" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "trash_me")

    put :trash, params: { :id => node.id }

    assert_redirected_to trashed_nodes_path
    assert node.reload.in_trash?
  end

  test "trashing the Trash node itself is refused" do
    login_as :quentin

    put :trash, params: { :id => Node.trash.id }

    assert_redirected_to node_path(Node.trash)
    assert flash[:error].present?
  end

  test "restore_from_trash reparents to the given parent" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "restore_me")
    node.trash!(users(:quentin))
    target = Node.root.children.create!(:slug => "restore_home")

    put :restore_from_trash, params: { :id => node.id, :parent_id => target.id }

    assert_redirected_to node_path(node)
    assert_equal target, node.reload.parent
  end

  test "destroy refuses a node outside the Trash" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "not_deletable_here")

    delete :destroy, params: { :id => node.id }

    assert Node.exists?(node.id)
    assert flash[:error].present?
  end

  test "destroy deletes a trashed node and redirects to the Trash" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "deletable")
    node.trash!(users(:quentin))

    delete :destroy, params: { :id => node.id }

    assert_not Node.exists?(node.id)
    assert_redirected_to trashed_nodes_path
  end

  test "trash lists trashed subtree roots" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "listed_in_trash")
    node.trash!(users(:quentin))

    get :trashed
    assert_response :success
    assert_select "a[href=?]", node_path(node)
  end

  test "trashed rows carry provenance and a delete for childless roots" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "provenance_test")
    node.trash!(users(:quentin))

    get :trashed
    assert_select "td", /quentin/
    assert_select "form[action=?]", node_path(node), count: 1
  end

test "show annotates history rows with their lifecycle" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "history_annotation_test")
    Globalize.with_locale(I18n.default_locale) { node.draft.update!(:title => "Annotated") }
    node.publish_draft!(users(:quentin))

    get :show, params: { :id => node.id }

    assert_response :success
    assert_select "span.revision_lifecycle", /quentin/
  end
end
