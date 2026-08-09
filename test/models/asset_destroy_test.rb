require "test_helper"

class AssetDestroyTest < ActiveSupport::TestCase
  def setup
    @user  = users(:quentin)
    @asset = Asset.create!(:name => "Doomed asset",
                            :upload_file_name => "doomed.png",
                            :upload_content_type => "image/png")
  end

  test "an unattached asset is still witnessed" do
    @asset.destroy_witnessed!(:user => @user)

    action = NodeAction.where(:action => "asset_destroy").last
    assert_equal [["Asset", @asset.id]],
                 action.action_participants.map { |p| [p.subject_type, p.subject_id] }
    assert_nil action.node_id
  end

  test "the entry outlives the asset" do
    @asset.destroy_witnessed!(:user => @user)
    action = NodeAction.where(:action => "asset_destroy").last

    assert_not Asset.exists?(@asset.id)
    assert_equal "Doomed asset", action.metadata["asset_name"]
    assert_nil action.action_participants.first.subject
  end

  test "destruction is refused while the asset is attached" do
    node = Node.root.children.create!(:slug => "asset_destroy_attached")
    node.attach_asset!(@asset, :user => @user)

    assert_raises(ActiveRecord::RecordInvalid) { @asset.destroy_witnessed!(:user => @user) }
    assert Asset.exists?(@asset.id)
    assert_equal 0, NodeAction.where(:action => "asset_destroy").count
  end

  test "an attachment on a draft alone is enough to refuse" do
    node = Node.root.children.create!(:slug => "asset_destroy_draft_only")
    node.attach_asset!(@asset, :user => @user)
    node.publish_draft!(@user)
    node.lock_for_editing!(@user)
    node.create_new_draft(@user)
    node.head.related_assets.destroy_all

    assert_raises(ActiveRecord::RecordInvalid) { @asset.destroy_witnessed!(:user => @user) }
    assert Asset.exists?(@asset.id)
  end
end
