require 'test_helper'

class ContentHelperTest < ActionView::TestCase
  test "weekday_abbr delegates through the current I18n locale" do
    I18n.with_locale(:de) do
      assert_equal "Mo", weekday_abbr(Time.parse("2026-07-06"))
    end
  end

  test "asset_credit returns nil for a nil asset" do
    assert_nil asset_credit(nil)
  end

  test "asset_credit returns nil when creator, source, and license are all blank" do
    assert_nil asset_credit(Asset.new(:name => "blank"))
  end

  test "asset_credit renders creator, source link, and license link when all are present" do
    asset = Asset.new(:name => "demo", :creator => "Jane Doe",
                       :source_url => "https://example.org/photo", :license_key => "cc_by_4")

    result = I18n.with_locale(:en) { asset_credit(asset) }

    assert_match %r{<a href="https://example.org/photo">Photo demo</a>}, result
    assert_match "by Jane Doe", result
    assert_match %r{<a href="https://creativecommons.org/licenses/by/4.0/">Licensed under CC BY 4.0</a>}, result
  end

  test "asset_credit falls back to plain text when source_url is blank" do
    asset = Asset.new(:name => "demo", :creator => "Jane Doe", :license_key => "cc_by_4")
    assert_no_match %r{<a href="[^"]*">Photo demo</a>}, I18n.with_locale(:en) { asset_credit(asset) }
  end

  test "asset_credit omits the 'by' clause when creator is blank" do
    asset = Asset.new(:name => "demo", :source_url => "https://example.org/photo", :license_key => "cc_by_4")
    assert_no_match "by ", I18n.with_locale(:en) { asset_credit(asset) }
  end

  test "a note-style license renders with no 'Licensed under' prefix and no link" do
    asset = Asset.new(:name => "demo", :creator => "CCC", :license_key => "own_work")
    result = I18n.with_locale(:en) { asset_credit(asset) }

    assert_match "Own work", result
    assert_no_match "Licensed under", result
    assert_no_match "<a", result
  end

  test "asset_credit degrades gracefully when the license_key is no longer in the dictionary" do
    asset = Asset.new(:name => "demo", :creator => "Jane Doe")
    asset.license_key = "a_retired_key"

    result = I18n.with_locale(:en) { asset_credit(asset) }

    assert_match "Photo demo by Jane Doe", result
    assert_no_match "Licensed under", result
  end

  test "headline_image renders nothing when no images are attached" do
    node = Node.root.children.create!(:slug => "headline_image_empty_test")
    @page = node.draft
    assert_nil headline_image
  end

  test "headline_image renders the flagged headline asset" do
    node = Node.root.children.create!(:slug => "headline_image_flagged_test")
    asset = Asset.create!(:name => "flagged", :upload_content_type => "image/png")
    node.draft.assets << asset
    node.draft.related_assets.find_by(:asset_id => asset.id).update!(:headline => true)
    @page = node.draft

    assert_match "glightbox", headline_image
  end

  test "headline_image falls back to a gallery-open caption when no headline is flagged" do
    node = Node.root.children.create!(:slug => "headline_image_no_flag_test")
    asset = Asset.create!(:name => "unflagged", :upload_content_type => "image/png")
    node.draft.assets << asset
    @page = node.draft

    I18n.with_locale(:en) { assert_match t(:open_gallery), headline_image }
  end

  test "headline_image renders a document card for a PDF headline, not a lightbox image" do
    node = Node.root.children.create!(:slug => "headline_image_pdf_test")
    asset = Asset.create!(:name => "Expert Opinion", :upload_content_type => "application/pdf")
    node.draft.assets << asset
    node.draft.related_assets.find_by(:asset_id => asset.id).update!(:headline => true)
    @page = node.draft

    result = headline_image

    assert_match "headline_document_card", result
    assert_match "Expert Opinion", result
    assert_no_match "data-gallery", result
  end

  test "headline_image lists other attached PDFs below the headline" do
    node = Node.root.children.create!(:slug => "headline_image_multi_pdf_test")
    headline_pdf = Asset.create!(:name => "Main Filing", :upload_content_type => "application/pdf")
    other_pdf = Asset.create!(:name => "Supplementary Exhibit", :upload_content_type => "application/pdf")
    node.draft.assets << headline_pdf
    node.draft.assets << other_pdf
    node.draft.related_assets.find_by(:asset_id => headline_pdf.id).update!(:headline => true)
    @page = node.draft

    result = headline_image

    assert_match "Main Filing", result
    assert_match "Supplementary Exhibit", result
    assert_match "headline_document_card", result
    assert_match "related_documents_list", result
  end

  test "headline_image lists attached PDFs even with no headline chosen" do
    node = Node.root.children.create!(:slug => "headline_image_pdf_no_headline_test")
    pdf_a = Asset.create!(:name => "Document A", :upload_content_type => "application/pdf")
    pdf_b = Asset.create!(:name => "Document B", :upload_content_type => "application/pdf")
    node.draft.assets << pdf_a
    node.draft.assets << pdf_b
    @page = node.draft

    result = headline_image

    assert_no_match "headline_document_card", result
    assert_match "Document A", result
    assert_match "Document B", result
  end
end
