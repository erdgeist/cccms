require "test_helper"

class NodeAttachAssetTest < ActiveSupport::TestCase

  def setup
    @user  = users(:quentin)
    @other = users(:aaron)
    @node  = Node.root.children.create!(:slug => "attach_asset_test")
    @image = create_image_asset
  end

  test "attaches to an existing draft" do
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 1, result[:attached]
    assert_not result[:draft_created]
    assert_includes @node.draft.assets, @image
  end

  test "creates a draft when none is pending and leaves head untouched" do
    @node.publish_draft!(@user)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 1, result[:attached]
    assert result[:draft_created]
    assert_includes @node.draft.assets, @image
    assert_empty @node.head.assets.reload
  end

  test "attaches to a pending draft and leaves head untouched" do
    @node.publish_draft!(@user)
    @node.lock_for_editing!(@user)
    @node.create_new_draft(@user)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 1, result[:attached]
    assert_not result[:draft_created]
    assert_includes @node.draft.assets, @image
    assert_empty @node.head.assets.reload
  end

  test "refuses when an autosave exists and writes nothing" do
    @node.publish_draft!(@user)
    @node.lock_for_editing!(@user)
    @node.create_new_draft(@user)
    @node.autosave!({ :title => "wip" }, @user)
    assert_raises(ActiveRecord::RecordInvalid) { @node.attach_asset!(@image, :user => @user) }
    assert_empty @node.draft.assets.reload
    assert_empty @node.autosave.assets.reload
  end

  test "reports an asset the draft already carries without duplicating it" do
    @node.draft.related_assets.create!(:asset => @image)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 0, result[:attached]
    assert_equal 1, result[:already]
    assert_not result[:draft_created]
    assert_equal 1, @node.draft.related_assets.where(:asset_id => @image.id).count
  end

  test "creates no draft when head already carries the asset" do
    @node.draft.related_assets.create!(:asset => @image)
    @node.publish_draft!(@user)
    assert_nil @node.draft

    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 0, result[:attached]
    assert_not result[:draft_created]
    assert_nil @node.reload.draft
  end

  test "attaching twice leaves one join row" do
    @node.attach_asset!(@image, :user => @user)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 0, result[:attached]
    assert_equal 1, @node.draft.related_assets.where(:asset_id => @image.id).count
  end

  test "refuses when another user holds the lock and writes nothing" do
    @node.lock_for_editing!(@other)
    assert_raises(LockedByAnotherUser) { @node.attach_asset!(@image, :user => @user) }
    assert_empty @node.draft.assets.reload
  end

  test "proceeds when the attaching user holds the lock" do
    @node.lock_for_editing!(@user)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 1, result[:attached]
  end

  test "sets the headline when none exists" do
    result = @node.attach_asset!(@image, :user => @user, :headline => true)
    assert_equal :set, result[:headline]
    assert_equal @image, @node.draft.headline_asset
  end

  test "keeps an existing headline and reports it" do
    incumbent = create_image_asset
    @node.draft.related_assets.create!(:asset => incumbent, :headline => true)
    result = @node.attach_asset!(@image, :user => @user, :headline => true)
    assert_equal :kept_existing, result[:headline]
    assert_equal incumbent, @node.draft.reload.headline_asset
    assert_includes @node.draft.assets, @image
  end

  test "keeps a headline the new draft inherited from head" do
    incumbent = create_image_asset
    @node.draft.related_assets.create!(:asset => incumbent, :headline => true)
    @node.publish_draft!(@user)

    result = @node.attach_asset!(@image, :user => @user, :headline => true)
    assert result[:draft_created]
    assert_equal :kept_existing, result[:headline]
    assert_equal incumbent, @node.draft.reload.headline_asset
  end

  test "declines the headline flag for ineligible asset types" do
    plain = create_plain_asset
    result = @node.attach_asset!(plain, :user => @user, :headline => true)
    assert_equal :not_eligible, result[:headline]
    assert_includes @node.draft.assets.reload, plain
    assert_nil @node.draft.headline_asset
  end

  test "refuses nodes in the Trash" do
    @node.trash!(@user)
    assert_raises(ActiveRecord::RecordInvalid) { @node.attach_asset!(@image, :user => @user) }
  end

  test "attaching writes no log entry -- publish carries the witnessing" do
    assert_no_difference "NodeAction.count" do
      @node.attach_asset!(@image, :user => @user)
    end
  end

  test "attaching under a restricted surface needs no redaktion role" do
    updates = Node.root.children.create!(:slug => "updates")
    node    = updates.children.create!(:slug => "gated-attachment")
    result  = node.reload.attach_asset!(@image, :user => @user)
    assert_equal 1, result[:attached]
  end

  private

    def create_image_asset
      Asset.create!(:name => "attach test image", :upload_content_type => "image/png")
    end

    def create_plain_asset
      Asset.create!(:name => "attach test note", :upload_content_type => "text/plain")
    end
end
