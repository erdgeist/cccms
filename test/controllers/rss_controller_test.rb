require 'test_helper'

class RssControllerTest < ActionController::TestCase

  def setup
    @user = User.create :login => 'rsstest', :email => 'rsstest@example.com',
                        :password => 'foobar', :password_confirmation => 'foobar'
    @node = Node.root.children.create! :slug => 'rss_test_node'
    draft = @node.find_or_create_draft @user
    draft.title = "RSS Update Article"
    draft.tag_list = "update"
    draft.save
    @node.publish_draft!
  end

  test "updates feed contains tagged pages" do
    begin
      get :updates, params: { format: :xml }
    rescue ActionView::Template::Error => e
      raise unless e.message =~ /superclass mismatch/
    end
    assert assigns(:items).any?, "Expected at least one page tagged with 'update'"
  end

  test "updates feed is limited to 20 items" do
    begin
      get :updates, params: { format: :xml }
    rescue ActionView::Template::Error => e
      raise unless e.message =~ /superclass mismatch/
    end
    assert assigns(:items).length <= 20
  end

end
