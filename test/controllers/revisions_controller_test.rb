require 'test_helper'

class RevisionsControllerTest < ActionController::TestCase

  def setup
    Node.root.descendants.destroy_all
    @user = User.find_by_login("aaron")
    @node = Node.root.children.create!( :slug => "version_me" )

    draft = @node.draft
    draft.body = "first"
    @node.publish_draft!
    @node.find_or_create_draft @user
    draft = @node.draft
    draft.update(:body => "second")
    @node.publish_draft!
  end

  test "setup" do
    assert_equal 2, Node.count
    assert_equal 2, @node.pages.count
    assert_equal ["first", "second"], @node.pages.map {|p| p.body}
  end

  test "get list of revisions for a given node" do
    login_as :quentin
    get :index, params: { :node_id => @node.id }
    assert_response :success
    assert_select ".revision", 2
  end

   test "showing one revision" do
    login_as :quentin
    get :show, params: { :node_id => @node.id, :id => @node.pages.last.id }
    assert_response :success
    assert_select ".node_description", "Body"
    assert_select ".node_content", {:count => 1, :text => "second"}
  end

  test "showing a revision renders real markup in the body, not escaped entities" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "show_markup_test")
    draft = node.draft
    draft.body = "<h3>Hello</h3>"
    node.publish_draft!

    get :show, params: { :node_id => node.id, :id => node.head.id }
    assert_response :success
    assert_select ".node_content h3", "Hello"
  end

  test "diffing two revisions" do
    login_as :quentin
    post(
      :diff, params: {
        :node_id => @node.id,
        :start_revision => @node.pages.first.revision,
        :end_revision => @node.pages.last.revision
      }
    )
    assert_response :success
  end

  test "restoring a revision" do
    assert_equal "second", @node.head.body

    login_as :aaron
    put( :restore, params: { :node_id => @node.id, :id => @node.pages.first.id } )

    @node.reload
    assert_equal @node.head, @node.pages.first
    assert_equal "first", @node.head.reload.body
  end

  test "diffing two revisions renders real markup with only the changed words marked" do
    login_as :quentin
    post(
      :diff, params: {
        :node_id => @node.id,
        :start_revision => @node.pages.first.revision,
        :end_revision => @node.pages.last.revision
      }
    )
    assert_response :success
    assert_select "del", "first"
    assert_select "ins", "second"
    assert_no_match /&lt;/, response.body
  end

  test "diffing two revisions in side by side view renders two columns" do
    login_as :quentin
    post(
      :diff, params: {
        :node_id => @node.id,
        :start_revision => @node.pages.first.revision,
        :end_revision => @node.pages.last.revision,
        :view => "side_by_side"
      }
    )
    assert_response :success
    assert_select ".diff_column", 2
  end

  test "diffing head against draft by name" do
    login_as :quentin
    @node.find_or_create_draft(@user)
    @node.draft.update(:body => "draft body")

    post(:diff, params: { :node_id => @node.id, :start_revision => "head", :end_revision => "draft" })
    assert_response :success
  end

  test "diffing a layer pair that no longer exists redirects with a flash" do
    login_as :quentin
    post(:diff, params: { :node_id => @node.id, :start_revision => "draft", :end_revision => "autosave" })
    assert_redirected_to node_path(@node)
    assert flash[:error].present?
  end

  test "diffing by name shows a clear comparison label instead of a misleading revision picker" do
    login_as :quentin
    @node.find_or_create_draft(@user)

    post(:diff, params: { :node_id => @node.id, :start_revision => "head", :end_revision => "draft" })
    assert_response :success
    assert_select "strong", "Head"
    assert_select "strong", "Draft"
    assert_select "select[name=?]", "start_revision", :count => 0
  end

  test "pair-switcher buttons carry their params as real hidden fields, not a query string" do
    login_as :quentin
    @node.find_or_create_draft(@user)
    @node.lock_for_editing!(@user)
    @node.autosave!({ :body => "unsaved" }, @user)

    post(:diff, params: { :node_id => @node.id, :start_revision => "head", :end_revision => "draft" })
    assert_response :success
    assert_select "form.computation input[type=hidden][name=start_revision]"
    assert_select "form.computation input[type=hidden][name=end_revision]"
  end
end
