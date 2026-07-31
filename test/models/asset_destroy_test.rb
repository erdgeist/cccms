require "test_helper"

class AssetDestroyTest < ActiveSupport::TestCase
  def setup
    @user  = users(:quentin)
    @asset = Asset.create!(:name => "Doomed asset",
                            :upload_file_name => "doomed.png",
                            :upload_content_type => "image/png")
  end

  test "destroying an attached asset logs nodes and asset as participants" do
    node = Node.root.children.create!(:slug => "asset_destroy_attached")
    node.attach_asset!(@asset, :user => @user)

    @asset.destroy_witnessed!(:user => @user)

    action = NodeAction.where(:action => "asset_destroy").last
    subjects = action.action_participants.map { |p| [p.subject_type, p.subject_id] }
    assert_includes subjects, ["Asset", @asset.id]
    assert_includes subjects, ["Node", node.id]
    assert_equal [node.unique_name], action.metadata["detached_from"]
  end

  test "records which nodes lost their headline" do
    node = Node.root.children.create!(:slug => "asset_destroy_headline")
    node.attach_asset!(@asset, :user => @user, :headline => true)

    @asset.destroy_witnessed!(:user => @user)

    action = NodeAction.where(:action => "asset_destroy").last
    assert_equal [node.unique_name], action.metadata["headline_removed_from"]
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

  test "destroying an asset attached to a restricted node needs the redaktion role" do
    editor = User.create!(:login => "asset_gate", :email => "ag@example.com",
                          :password => "secret", :password_confirmation => "secret")
    updates = Node.root.children.create!(:slug => "updates")
    node    = updates.children.create!(:slug => "gated-attachment")
    node.reload.attach_asset!(@asset, :user => nil)

    error = assert_raises(ActiveRecord::RecordInvalid) { @asset.destroy_witnessed!(:user => editor) }
    assert_includes error.message,
                    I18n.t("activerecord.errors.models.asset.attributes.base.not_permitted")
    assert Asset.exists?(@asset.id)
  end
end
