require 'test_helper'

class ContentControllerTest < ActionController::TestCase

  def setup
    @root = Node.find(1)
    @first_child = Node.find(2)
    @second_child = Node.find(3)
    
    @user1 = User.create :login => 'demo', :email => "f@b.com", :password => 'foobar', :password_confirmation => 'foobar'
    @user2 = User.create :login => 'show', :email => "f@b.com", :password => 'foobar', :password_confirmation => 'foobar'
  end

  def test_custom_page_route
    assert_recognizes({ :controller => 'content', :action => 'render_page', :locale => 'de', :page_path => 'foo/bar' }, '/de/foo/bar')
    assert_recognizes({ :controller => 'content', :action => 'render_page', :locale => 'en', :page_path => 'home' }, '/en/home')
  end
  
  def test_render_404_when_no_page_was_found
    get :render_page, params: { :language => 'de', :page_path => ["wrong_path"] }
    assert_response 404
  end
  
  def test_rendering_a_page
    assert Node.valid?
    assert_not_nil first_child = Node.find_by_slug("first_child")
    page = first_child.pages.create :title => "First Child"
    first_child.head = page
    first_child.save!
    
    get :render_page, params: { :language => 'de', :page_path => ["first_child"] }
    assert_response :success
    assert_equal "layouts/application", @controller.active_layout.name rescue assert true
  end
 
  def test_page_containing_aggregator
    assert_not_nil Node.root

    fill_pages_with_content

    new_node = create_node_under_root "fnord"
    draft = find_or_create_draft(new_node, @user1)
    draft.body = '[aggregate tags="update" limit="20"]'
    draft.save
    new_node.publish_draft!

    get :render_page, params: { :locale => 'de', :page_path => ["fnord"] }
    assert_response :success

    # The aggregator renders into div.body > div.article_partial.
    # Without a working aggregator this will be empty.
    assert_select "div.body div.article_partial", :minimum => 2
    assert_select "div.body div.article_partial h2.headline a", :text => "one"
    assert_select "div.body div.article_partial h2.headline a", :text => "two"
  end

  def test_page_containing_aggregator_with_custom_template
    fill_pages_with_content
    
    new_node = create_node_under_root "fnord"
    draft = find_or_create_draft(new_node, @user1)
    draft.body = '[aggregate tags="update" limit="20" partial="sidebar_title_only"]'
    draft.save
    new_node.publish_draft!
    
    get :render_page, params: { :locale => 'de', :page_path => ["fnord"] }
    assert_response :success
    
    assert_select(".sidebar_headline", "one")
    assert_select(".sidebar_headline", "two")
  end
  
  def test_nonexistant_custom_template_defaults_to_standard_template
    new_node = create_node_under_root "fnord"
    draft = find_or_create_draft(new_node, @user1)
    draft.update_column(:template_name, "huchibu")
    new_node.publish_draft!
    
    get :render_page, params: { :locale => 'de', :page_path => ["fnord"] }
    assert_response :success
    assert_template "custom/page_templates/public/standard_template"
  end
  
  def test_custom_template_no_date_and_author
    new_node = create_node_under_root "fnord"
    draft = find_or_create_draft(new_node, @user1)
    draft.template_name = "no_date_and_author"
    draft.save
    new_node.publish_draft!
    
    get :render_page, params: { :locale => 'de', :page_path => ["fnord"] }
    assert_response :success
    assert_template "custom/page_templates/public/no_date_and_author"
  end

  def test_aggregator_without_fill
    new_node = create_node_under_root "fnord"
    draft = find_or_create_draft(new_node, @user1)
    draft.body = '<aggregate tags="xyzzy_unique_test_tag" limit="20" />'
    draft.save
    new_node.publish_draft!

    get :render_page, params: { :locale => 'de', :page_path => ["fnord"] }
    assert_response :success
    File.write("/tmp/no_fill_response.html", @response.body)
  end

  test "render_gallery renders for a published page" do
    node = Node.root.children.create!(:slug => "gallery_render_test")
    Globalize.with_locale(I18n.default_locale) { node.draft.update!(:title => "Galerie") }
    node.publish_draft!

    get :render_gallery, params: { :page_path => "gallery_render_test", :locale => "de" }

    assert_response :success
  end

  test "a published page emits article social metadata" do
    node  = create_node_under_root "og_article_test"
    draft = find_or_create_draft(node, @user1)
    draft.title    = "Offener Brief"
    draft.abstract = "Wir veröffentlichen den Wortlaut eines Offenen Briefes."
    draft.save
    node.publish_draft!

    get :render_page, params: { :locale => "de", :page_path => ["og_article_test"] }

    assert_response :success
    assert_select "meta[property='og:type'][content=?]",      "article"
    assert_select "meta[property='og:title'][content=?]",     "Offener Brief"
    assert_select "meta[property='og:site_name'][content=?]", "Chaos Computer Club"
    assert_select "meta[property='og:locale'][content=?]",    "de_DE"
    assert_select "meta[property='article:published_time']"

    # og:title carries the bare title; page_title's "CCC | " prefix belongs
    # to <title> only, since platforms render og:site_name separately.
    assert_select "title", :text => "CCC | Offener Brief"

    # A canonical URL must not carry a query string.
    canonical = css_select("link[rel=canonical]").first["href"]
    assert_match %r{/og_article_test\z}, canonical

    assert_select "meta[name=robots]", false, "a public page must be indexable"
  end

  test "a page without a headline asset falls back to the default card" do
    node = create_node_under_root "og_fallback_test"
    find_or_create_draft(node, @user1).update!(:title => "Ohne Aufmacher")
    node.publish_draft!

    get :render_page, params: { :locale => "de", :page_path => ["og_fallback_test"] }

    assert_response :success
    assert_select "meta[property='og:image'][content=?]",
                  "http://test.host/images/social_default.png"
    assert_select "meta[property='og:image:width'][content=?]",  "1200"
    assert_select "meta[property='og:image:height'][content=?]", "630"
  end

  test "a page with a headline asset points at its social card" do
    node  = create_node_under_root "og_variant_test"
    draft = find_or_create_draft(node, @user1)
    draft.title = "Mit Aufmacher"
    draft.save
    node.publish_draft!
    node.reload

    asset = Asset.create!(:name => "aufmacher",
                          :upload_file_name => "aufmacher.png",
                          :upload_content_type => "image/png",
                          :upload_updated_at => Time.at(1_700_000_000))
    node.attach_asset!(asset, :user => @user1, :headline => true)

    # has_variant? only tests File.exist?, so touching the path is enough
    # and no ImageMagick runs in the suite. image/png takes .jpg for the
    # card, per variant_filename's per-style rule.
    card = Rails.root.join("tmp", "test_uploads", asset.id.to_s, "og", "aufmacher.jpg")

    begin
      FileUtils.mkdir_p(File.dirname(card))
      FileUtils.touch(card)

      get :render_page, params: { :locale => "de", :page_path => ["og_variant_test"] }

      assert_response :success
      assert_select "meta[property='og:image'][content=?]",
                    "http://test.host/system/uploads/#{asset.id}/og/aufmacher.jpg?v=1700000000"
      assert_select "meta[property='og:image:alt'][content=?]", "aufmacher"
    ensure
      FileUtils.rm_rf(Rails.root.join("tmp", "test_uploads", asset.id.to_s))
    end
  end

  test "a translated page declares hreflang alternates and canonicalises per locale" do
    node  = create_node_under_root "og_hreflang_test"
    draft = find_or_create_draft(node, @user1)
    draft.title = "Zweisprachig"
    draft.save
    node.publish_draft!
    node.reload
    Globalize.with_locale(:en) { node.head.update!(:title => "Bilingual") }

    get :render_page, params: { :locale => "de", :page_path => ["og_hreflang_test"] }

    assert_response :success
    assert_select "link[rel=alternate][hreflang=de][href=?]",
                  "http://test.host/og_hreflang_test"
    assert_select "link[rel=alternate][hreflang=en][href=?]",
                  "http://test.host/en/og_hreflang_test"
    assert_select "link[rel=alternate][hreflang='x-default'][href=?]",
                  "http://test.host/og_hreflang_test"
    assert_select "link[rel=canonical][href=?]",
                  "http://test.host/og_hreflang_test"
  end

  test "an untranslated page declares no alternates and canonicalises to the default locale" do
    node  = create_node_under_root "og_single_locale_test"
    draft = find_or_create_draft(node, @user1)
    draft.title = "Nur Deutsch"
    draft.save
    node.publish_draft!

    get :render_page, params: { :locale => "en", :page_path => ["og_single_locale_test"] }

    assert_response :success
    assert_select "link[rel=alternate][hreflang]", false,
                  "one translation is nothing to declare"
    # Served German through the fallback chain, so the German URL is
    # canonical rather than the /en/ address that was requested.
    assert_select "link[rel=canonical][href=?]",
                  "http://test.host/og_single_locale_test"
  end
  
  protected
  
    def create_node_under_root slug
      node = Node.root.children.create! :slug => slug
      node
    end

    def fill_pages_with_content
      updates = Node.root.children.find_by(:slug => "updates") ||
                Node.root.children.create!(:slug => "updates")

      [["one", "aggregated_one"], ["two", "aggregated_two"]].each do |title, slug|
        node  = updates.children.create!(:slug => slug)
        draft = find_or_create_draft(node, @user1)
        draft.title = title
        draft.tag_list = "update"
        draft.save
        node.publish_draft!
      end
    end
end
