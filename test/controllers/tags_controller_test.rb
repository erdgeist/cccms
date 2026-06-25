require 'test_helper'

class TagsControllerTest < ActionController::TestCase

  def setup
    @user = User.create :login => 'tagtest', :email => 'tagtest@example.com',
                        :password => 'foobar', :password_confirmation => 'foobar'
    @node = Node.root.children.create! :slug => 'tag_test_node'
    draft = @node.find_or_create_draft @user
    draft.title = "Tagged Article"
    draft.tag_list = "testtag"
    draft.save
    @node.publish_draft!
  end

  test "show returns pages tagged with the requested tag" do
    get :show, params: { id: 'testtag', locale: 'de' }
    assert_response :success
    assert assigns(:pages).any?, "Expected at least one page tagged with 'testtag'"
    assert assigns(:pages).all? { |p| p.is_a?(Page) }
  end

  test "show with unknown tag returns empty collection" do
    get :show, params: { id: 'nonexistent_tag_xyz', locale: 'de' }
    assert_response :success
    assert assigns(:pages).empty?
  end

  test "show with invalid tag characters returns 400" do
    get :show, params: { id: '<script>alert(1)</script>', locale: 'de' }
    assert_response 400
  end

end
