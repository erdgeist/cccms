require 'test_helper'

class RssControllerTest < ActionController::TestCase

  def setup
    @user = User.create :login => 'rsstest', :email => 'rsstest@example.com',
                        :password => 'foobar', :password_confirmation => 'foobar'
    updates = Node.root.children.find_by(:slug => "updates") ||
              Node.root.children.create!(:slug => "updates")
    @node = updates.children.create! :slug => 'rss_test_node'
    draft = find_or_create_draft(@node, @user)
    draft.title = "RSS Update Article"
    draft.tag_list = "update"
    draft.save
    @node.publish_draft!
  end

  test "updates feed contains tagged pages" do
    get :updates, params: { format: :xml }
    assert assigns(:items).any?, "Expected at least one page tagged with 'update'"
  end

  test "updates feed is limited to 20 items" do
    get :updates, params: { format: :xml }
    assert assigns(:items).length <= 20
  end

  test "the update feed excludes a page tagged update outside /updates" do
    updates = Node.root.children.find_by(:slug => "updates")
    inside  = updates.children.create!(:slug => "feed-inside")
    outside = Node.root.children.create!(:slug => "feed-outside")

    [inside, outside].each do |node|
      node.reload.draft.update!(:title => node.slug, :tag_list => "update")
      node.publish_draft!
    end

    get :updates, params: { :format => :xml }

    assert_response :success
    assert_includes     @response.body, "feed-inside"
    assert_not_includes @response.body, "feed-outside"
  end
end
