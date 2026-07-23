require 'test_helper'

class AssetsControllerTest < ActionController::TestCase

  def setup
    login_as :quentin
    @existing_asset_ids = Asset.pluck(:id)
  end

  def teardown
    (Asset.pluck(:id) - @existing_asset_ids).each do |id|
      dir = Asset.upload_root.join(id.to_s)
      raise "Refusing to delete #{dir} -- outside tmp/, Rails.env.test? may be false" unless
        dir.to_s.start_with?(Rails.root.join("tmp").to_s)
      FileUtils.rm_rf(dir)
    end
  end

  # --- index ---

  test "get index" do
    get :index
    assert_response :success
  end

  # --- show ---

  test "show existing asset" do
    asset = Asset.create!(
      name: 'Test asset',
      upload_file_name: 'test_image.png',
      upload_content_type: 'image/png',
      upload_file_size: 49854,
      upload_updated_at: Time.current
    )
    get :show, params: { id: asset.id }
    assert_response :success
  end

  # --- new ---

  test "get new" do
    get :new
    assert_response :success
  end

  # --- create with image ---

  test "create asset with image upload generates variants" do
    uploaded = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_image.png'),
      'image/png'
    )
    assert_difference 'Asset.count', 1 do
      post :create, params: { asset: { name: 'Logo', upload: uploaded } }
    end
    assert_response :redirect

    asset = Asset.last
    assert_equal 'test_image.png', asset.upload_file_name
    assert_equal 'image/png',      asset.upload_content_type
    assert asset.upload_file_size > 0

    # original and all four variants should exist on disk
    %w[original medium thumb headline large].each do |style|
      path = asset.send(:file_path, style)
      assert File.exist?(path), "Expected #{style} variant at #{path}"
    end
  end

  # --- create with PDF ---

  test "create asset with PDF upload generates rasterized variants" do
    uploaded = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_document.pdf'),
      'application/pdf'
    )
    assert_difference 'Asset.count', 1 do
      post :create, params: { asset: { name: 'Document', upload: uploaded } }
    end
    assert_response :redirect

    asset = Asset.last
    original_path = asset.send(:file_path, :original)
    assert File.exist?(original_path), "Expected original at #{original_path}"
    assert_equal 'test_document.pdf', File.basename(original_path)

    %w[medium thumb headline large].each do |style|
      path = asset.send(:file_path, style)
      assert File.exist?(path), "Expected a #{style} variant at #{path}"
      assert_equal '.png', File.extname(path), "Expected #{style} variant to be a PNG, not a PDF"
    end
  end

  # --- create with attach ---

  test "create with node_id attaches the asset to the node's draft" do
    node = Node.root.children.create!(:slug => "asset_attach_target")

    post :create, params: { asset: { name: 'Attach me' }, node_id: node.id }

    assert_response :redirect
    asset = Asset.last
    assert_includes node.draft.assets.reload, asset
    assert_match /attached/, flash[:notice]
  end

  test "create against a foreign-locked node keeps the asset but refuses the attach" do
    node = Node.root.children.create!(:slug => "asset_attach_locked")
    node.lock_for_editing!(users(:aaron))

    assert_difference 'Asset.count', 1 do
      post :create, params: { asset: { name: 'Orphaned for now' }, node_id: node.id }
    end

    assert_empty node.draft.assets.reload
    assert_equal node_path(node), flash[:locked_node_path]
    assert_equal "aaron", flash[:locked_by]
  end

  test "create with headline against a page that has one keeps the incumbent and warns" do
    node = Node.root.children.create!(:slug => "asset_attach_headline")
    incumbent = Asset.create!(:name => 'Incumbent', :upload_content_type => 'image/png')
    node.draft.related_assets.create!(:asset => incumbent, :headline => true)

    uploaded = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_image.png'), 'image/png')
    post :create, params: { asset: { name: 'Challenger', upload: uploaded },
                            node_id: node.id, headline: "1" }

    assert_includes node.draft.assets.reload, Asset.last
    assert_equal incumbent, node.draft.reload.headline_asset
    assert_equal node_path(node), flash[:headline_kept_path]
  end

  # --- edit ---

  test "get edit" do
    asset = Asset.create!(
      name: 'Edit me',
      upload_file_name: 'test_image.png',
      upload_content_type: 'image/png',
      upload_file_size: 49854,
      upload_updated_at: Time.current
    )
    get :edit, params: { id: asset.id }
    assert_response :success
  end

  # --- update ---

  test "update asset name" do
    asset = Asset.create!(
      name: 'Old name',
      upload_file_name: 'test_image.png',
      upload_content_type: 'image/png',
      upload_file_size: 49854,
      upload_updated_at: Time.current
    )
    put :update, params: { id: asset.id, asset: { name: 'New name' } }
    assert_response :redirect
    assert_equal 'New name', asset.reload.name
  end

  # --- destroy ---

  test "destroy asset removes record and files" do
    # Create a real upload so there are files to delete
    uploaded = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_image.png'),
      'image/png'
    )
    post :create, params: { asset: { name: 'To be deleted', upload: uploaded } }
    asset = Asset.last
    upload_dir = asset.send(:upload_root).join(asset.id.to_s)
    assert Dir.exist?(upload_dir), "Upload directory should exist before destroy"

    assert_difference 'Asset.count', -1 do
      delete :destroy, params: { id: asset.id }
    end
    assert_response :redirect
    assert !Dir.exist?(upload_dir), "Upload directory should be removed after destroy"
  end

  test "destroy is witnessed in the action log with the current user" do
    asset = Asset.create!(:name => 'Witness me',
                           :upload_file_name => 'w.png',
                           :upload_content_type => 'image/png')
    assert_difference 'NodeAction.where(:action => "asset_destroy").count' do
      delete :destroy, params: { id: asset.id }
    end
    assert_equal users(:quentin), NodeAction.last.user
  end

  # --- URL helpers ---

  test "upload url returns correct path for original" do
    asset = Asset.create!(
      name: 'URL test',
      upload_file_name: 'logo.png',
      upload_content_type: 'image/png',
      upload_file_size: 1000,
      upload_updated_at: Time.current
    )
    assert_equal "/system/uploads/#{asset.id}/original/logo.png", asset.upload.url
    assert_equal "/system/uploads/#{asset.id}/thumb/logo.png",    asset.upload.url(:thumb)
    assert_equal "/system/uploads/#{asset.id}/medium/logo.png",   asset.upload.url(:medium)
    assert_equal "/system/uploads/#{asset.id}/headline/logo.png", asset.upload.url(:headline)
    assert_equal "/system/uploads/#{asset.id}/large/logo.png",    asset.upload.url(:large)
  end

  # --- login required ---

  test "index requires login" do
    session[:user_id] = nil
    @controller.instance_variable_set(:@current_user, nil)
    get :index
    assert_response :redirect
  end
end
