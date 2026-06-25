require 'test_helper'

class AssetsControllerTest < ActionController::TestCase

  def setup
    login_as :quentin
  end

  def teardown
    # Clean up any files written to disk during tests
    Dir.glob(Rails.root.join('public', 'system', 'uploads', 'test_*')).each do |dir|
      FileUtils.rm_rf(dir)
    end
    # Remove uploads created for assets created during tests
    Asset.where("upload_file_name IS NOT NULL").where("id > 1000000").each do |a|
      FileUtils.rm_rf(Rails.root.join('public', 'system', 'uploads', a.id.to_s))
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

    # original and all three variants should exist on disk
    %w[original medium thumb headline].each do |style|
      path = Rails.root.join('public', 'system', 'uploads',
                             asset.id.to_s, style, 'test_image.png')
      assert File.exist?(path), "Expected #{style} variant at #{path}"
    end
  end

  # --- create with PDF ---

  test "create asset with PDF upload generates only original" do
    uploaded = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_document.pdf'),
      'application/pdf'
    )
    assert_difference 'Asset.count', 1 do
      post :create, params: { asset: { name: 'Document', upload: uploaded } }
    end
    assert_response :redirect

    asset = Asset.last
    assert_equal 'test_document.pdf', asset.upload_file_name
    assert_equal 'application/pdf',   asset.upload_content_type

    # only original should exist, no image variants
    original_path = Rails.root.join('public', 'system', 'uploads',
                                    asset.id.to_s, 'original', 'test_document.pdf')
    assert File.exist?(original_path), "Expected original at #{original_path}"

    %w[medium thumb headline].each do |style|
      path = Rails.root.join('public', 'system', 'uploads',
                             asset.id.to_s, style, 'test_document.pdf')
      assert !File.exist?(path), "Expected no #{style} variant for PDF"
    end
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
    upload_dir = Rails.root.join('public', 'system', 'uploads', asset.id.to_s)
    assert Dir.exist?(upload_dir), "Upload directory should exist before destroy"

    assert_difference 'Asset.count', -1 do
      delete :destroy, params: { id: asset.id }
    end
    assert_response :redirect
    assert !Dir.exist?(upload_dir), "Upload directory should be removed after destroy"
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
  end

  # --- login required ---

  test "index requires login" do
    session[:user_id] = nil
    @controller.instance_variable_set(:@current_user, nil)
    get :index
    assert_response :redirect
  end
end
