require "test_helper"

class NodeAttachAssetTest < ActiveSupport::TestCase

  def setup
    @user  = users(:quentin)
    @other = users(:aaron)
    @node  = Node.root.children.create!(:slug => "attach_asset_test")
    @image = create_image_asset
  end

  test "attaches to a draft-only node" do
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 1, result[:attached]
    assert_includes @node.draft.assets, @image
  end

  test "attaches to head when no draft is pending" do
    @node.publish_draft!(@user)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 1, result[:attached]
    assert_includes @node.head.assets, @image
  end

  test "attaches to head and pending draft alike" do
    @node.publish_draft!(@user)
    @node.lock_for_editing!(@user)
    @node.create_new_draft(@user)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 2, result[:attached]
    assert_includes @node.head.assets, @image
    assert_includes @node.draft.assets, @image
  end

  test "attaches to all three lifecycle rows" do
    @node.publish_draft!(@user)
    @node.lock_for_editing!(@user)
    @node.create_new_draft(@user)
    @node.autosave!({ :title => "wip" }, @user)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 3, result[:attached]
    [@node.head, @node.draft, @node.autosave].each do |row|
      assert_includes row.assets, @image
    end
  end

  test "skips rows that already carry the asset" do
    @node.draft.related_assets.create!(:asset => @image)
    @node.publish_draft!(@user)
    @node.lock_for_editing!(@user)
    @node.create_new_draft(@user)
    result = @node.attach_asset!(@image, :user => @user)
    assert_equal 0, result[:attached]
    assert_equal 2, result[:already]
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

  private

    def create_image_asset
      Asset.create!(:name => "attach test image", :upload_content_type => "image/png")
    end

    def create_plain_asset
      Asset.create!(:name => "attach test note", :upload_content_type => "text/plain")
    end
end
