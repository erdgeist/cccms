require 'test_helper'

class PageTest < ActiveSupport::TestCase
  
  def setup
    @user1 = User.create :login => 'demo', :email => "f@b.com", :password => 'foobar', :password_confirmation => 'foobar'
    @user2 = User.create :login => 'show', :email => "f@b.com", :password => 'foobar', :password_confirmation => 'foobar'
  end
  
  def test_aggregation
    # Create two nodes and move them beneath the root node
    updates = Node.root.children.create! :slug => "updates"
    n1 = updates.children.create! :slug => "one"
    n2 = updates.children.create! :slug => "two"
    
    # get the drafts and assign a user to it
    assert_not_nil d1 = find_or_create_draft(n1, @user1)
    assert_not_nil d3 = find_or_create_draft(n2, @user1)
    
    # tag and double publish so we have 4 pages tagged with "update"
    d1.tag_list = "update"
    d1.save
    n1.publish_draft!
  
    d2 = find_or_create_draft(n1, @user1)
    n1.publish_draft!
    
    
    d3.tag_list = "update, pressemitteilung"
    d3.save
    n2.publish_draft!
  
    d4 = find_or_create_draft(n2, @user1)
    n2.publish_draft!
    
    # Set up two options hashes for the assertions
    options1 = {
      :tags => "update"
    }
    
    options2 = {
      :tags => "update, pressemitteilung"
    }
    
    assert_equal 2, Page.aggregate( options1 ).length
    assert_equal 1, Page.aggregate( options2 ).length
    assert_equal 4, Page.tagged_with( "update" ).length
    assert_equal [d2.id, d4.id], Page.aggregate( options1 ).map {|x| x.id}
  end
  
  def test_before_save_rewrite_links_in_body
    n = Node.root.children.create :slug => "link_test"
    d = find_or_create_draft(n, @user1)
    
    before = "<h1>Hello World</h1>\n" \
             "<a href=\"/club\" target=\"_blank\">Linkme</a>"
    
    after  = "<h1>Hello World</h1>\n" \
             "<a href=\"/de/club\" target=\"_blank\">Linkme</a>"
    
    I18n.locale = :de
    
    d.body = before
    d.save!
    
    assert_equal after, d.body
  end
  
  def test_before_save_rewrite_links_in_body_if_no_locale_prefix_present
    n = Node.root.children.create :slug => "link_test"
    d = find_or_create_draft(n, @user1)
    
    before = "<h1>Hello World</h1>\n" \
             "<a href=\"/de/club\" target=\"_blank\">Linkme</a>"
    
    after  = "<h1>Hello World</h1>\n" \
             "<a href=\"/de/club\" target=\"_blank\">Linkme</a>"
    
    I18n.locale = :de
    
    d.body = before
    d.save
    
    assert_equal after, d.body
  end
  
  def test_before_save_rewrite_links_skips_on_external_links
    n = Node.root.children.create :slug => "link_test"
    d = find_or_create_draft(n, @user1)
    
    before = "<h1>Hello World</h1>\n" \
             "<a href=\"http://www.ccc.de/club\" target=\"_blank\">Linkme</a>"
    
    after  = "<h1>Hello World</h1>\n" \
             "<a href=\"http://www.ccc.de/club\" target=\"_blank\">Linkme</a>"
    
    I18n.locale = :de
    
    d.body = before
    d.save
    
    assert_equal after, d.body
  end
  
  def test_find_with_outdated_translations
    Node.delete_all
    Page.delete_all
    I18n.locale = :de
    
    assert_not_nil page = Page.create!( :title => "Hallo" )
    page.reload
    assert_equal 1, page.translations.size
    assert_equal [], Page.find_with_outdated_translations
    
    I18n.locale = :en
    page.title = "Hello"
    page.save
    
    assert_equal 2, page.translations.size
    assert_equal 0, Page.find_with_outdated_translations.size
    
    english = page.translations.select {|x| x.locale == :en}.first
    Page::Translation.record_timestamps = false
    english.update(:updated_at => (Time.now+25.hours))    
    Page::Translation.record_timestamps = true
    assert_equal 1, Page.find_with_outdated_translations.count
    
    I18n.locale = :de
    page2 = Page.create!( :title => "Hallo2" )
    I18n.locale = :en
    page2.title = "Hello2"
    page2.save!
    
    assert_equal 0, Page.find_with_outdated_translations(:delta_time => 23.days).count
    assert_equal 1, Page.find_with_outdated_translations(:delta_time => 23.minutes).count
    assert_equal 2, Page.count
  end
  
  test "pages under /updates node get the update template assigned" do
    Node.root.descendants.delete_all
    updates       = Node.root.children.create!( :slug => "updates" )
    updates2009   = updates.children.create!( :slug => "2009" )
    update        = updates2009.children.create!( :slug => "my-first-update" )
    assert_equal "update", update.draft.template_name
  end

  test "a page scheduled for future publication is not yet public even after being published" do
    node = Node.root.children.create!(slug: "preview-scheduled-test")
    draft = find_or_create_draft(node, @user1)
    draft.title = "Scheduled test"
    draft.published_at = 1.day.from_now
    draft.save!
    token = draft.ensure_preview_token!

    node.publish_draft!
    page = Page.find_by(preview_token: token)

    assert_equal page.id, page.node.head_id
    assert_not page.public?
  end

  test "a superseded page is no longer the head, even though it was once published" do
    node = Node.root.children.create!(slug: "preview-superseded-test")
    first_draft = find_or_create_draft(node, @user1)
    first_draft.title = "First version"
    first_draft.save!
    first_token = first_draft.ensure_preview_token!
    node.publish_draft!

    second_draft = find_or_create_draft(node, @user1)
    second_draft.title = "Second version"
    second_draft.save!
    node.publish_draft!

    first_page = Page.find_by(preview_token: first_token)

    assert_not_equal first_page.id, first_page.node.head_id
    assert first_page.published_at.present?
  end

  test "clone_attributes_from preserves an unchanged locale's original timestamp" do
    n = Node.root.children.create!(:slug => "clone_preserve_timestamp_test")
    source = n.draft
    Globalize.with_locale(:de) { source.update!(:title => "Deutscher Titel") }
    Globalize.with_locale(:en) { source.update!(:title => "English Title") }

    target = Page.create!
    target.clone_attributes_from(source)
    original_en_updated_at = target.translations.find_by(:locale => :en).updated_at

    Globalize.with_locale(:de) { source.update!(:title => "Deutscher Titel (bearbeitet)") }
    target.clone_attributes_from(source)

    en_translation = target.translations.find_by(:locale => :en)
    assert_equal "English Title", en_translation.title
    assert_equal original_en_updated_at, en_translation.updated_at
  end

  test "clone_attributes_from gives a genuinely changed locale a fresh timestamp" do
    n = Node.root.children.create!(:slug => "clone_fresh_timestamp_test")
    source = n.draft
    Globalize.with_locale(:de) { source.update!(:title => "Erste Version") }

    target = Page.create!
    target.clone_attributes_from(source)
    original_de_updated_at = target.translations.find_by(:locale => :de).updated_at

    Globalize.with_locale(:de) { source.update!(:title => "Zweite Version") }
    target.clone_attributes_from(source)

    de_translation = target.translations.find_by(:locale => :de)
    assert_equal "Zweite Version", de_translation.title
    assert_operator de_translation.updated_at, :>, original_de_updated_at
  end

  test "clone_attributes_from removes a locale no longer present in the source" do
    n = Node.root.children.create!(:slug => "clone_removed_locale_test")
    source = n.draft
    Globalize.with_locale(:en) { source.update!(:title => "English Title") }

    target = Page.create!
    target.clone_attributes_from(source)
    assert_includes target.translations.map(&:locale), :en

    source.translations.where(:locale => :en).delete_all
    target.clone_attributes_from(source)

    assert_not_includes target.reload.translations.map(&:locale), :en
  end

  def test_diff_against_inline_keeps_tags_and_marks_only_the_changed_word
    n = Node.root.children.create! :slug => "diff_against_test"
    d = find_or_create_draft(n, @user1)
    d.title = "Old heading"
    d.save!
    n.publish_draft!

    d2 = find_or_create_draft(n, @user1)
    d2.title = "New heading"
    d2.save!

    diff = d2.diff_against(n.head)

    assert_match "<del>Old</del>", diff[:title]
    assert_match "<ins>New</ins>", diff[:title]
  end

  def test_diff_against_side_by_side_returns_two_annotated_strings
    n = Node.root.children.create! :slug => "diff_against_sbs_test"
    d = find_or_create_draft(n, @user1)
    d.title = "Old heading"
    d.save!
    n.publish_draft!

    d2 = find_or_create_draft(n, @user1)
    d2.title = "New heading"
    d2.save!

    old_html, new_html = d2.diff_against(n.head, view: :side_by_side)[:title]

    assert_match "<del>Old</del>", old_html
    assert_match "<ins>New</ins>", new_html
  end

  test "diff_against handles an inserted paragraph split without corrupting the document" do
    n = Node.root.children.create! :slug => "paragraph_split_test"
    d = find_or_create_draft(n, @user1)
    d.body = "<p>Der Vortragsraum ist ab 19 Uhr geöffnet, der Zugang erfolgt über den Hinterhof.</p>"
    d.save!
    n.publish_draft!

    d2 = find_or_create_draft(n, @user1)
    d2.body = "<p>Der Vortragsraum ist ab 19 Uhr geöffnet,</p>\n<p>der Zugang erfolgt über den Hinterhof.</p>"
    d2.save!

    diff = d2.diff_against(n.head)
    fragment = Nokogiri::HTML::DocumentFragment.parse(diff[:body])

    assert_equal 2, fragment.css('ins.diff_structural').length
    assert_match "der Zugang erfolgt über den Hinterhof.", fragment.text
  end

  test "diff_against reports tag and template changes" do
    n = Node.root.children.create! :slug => "field_diff_test"
    d = find_or_create_draft(n, @user1)
    d.tag_list = "update"
    d.template_name = "standard_template"
    d.save!
    n.publish_draft!

    d2 = find_or_create_draft(n, @user1)
    d2.tag_list = "update, pressemitteilung"
    d2.template_name = "title_only"
    d2.save!

    diff = d2.diff_against(n.head)

    assert_equal ["pressemitteilung"], diff[:tags][:added]
    assert_equal [], diff[:tags][:removed]
    assert diff[:template_name][:changed]
    assert_equal "standard_template", diff[:template_name][:from]
    assert_equal "title_only", diff[:template_name][:to]
  end

  test "diff_against reports added and removed assets by filename" do
    n = Node.root.children.create! :slug => "asset_diff_test"
    d = find_or_create_draft(n, @user1)
    d.save!
    n.publish_draft!

    kept_asset    = Asset.create!(:upload_file_name => "kept.png", :upload_content_type => "image/png", :upload_file_size => 1)
    removed_asset = Asset.create!(:upload_file_name => "removed.pdf", :upload_content_type => "application/pdf", :upload_file_size => 1)
    n.head.related_assets.delete_all
    n.head.related_assets.create!(:asset_id => kept_asset.id, :position => 1)
    n.head.related_assets.create!(:asset_id => removed_asset.id, :position => 2)

    d2 = find_or_create_draft(n, @user1)
    added_asset = Asset.create!(:upload_file_name => "added.png", :upload_content_type => "image/png", :upload_file_size => 1)
    d2.related_assets.delete_all
    d2.related_assets.create!(:asset_id => kept_asset.id, :position => 1)
    d2.related_assets.create!(:asset_id => added_asset.id, :position => 2)
    d2.save!

    diff = d2.diff_against(n.head)

    assert_equal [added_asset], diff[:assets][:added]
    assert_equal [removed_asset], diff[:assets][:removed]
  end

  test "diff_against with an explicit locale compares that locale's own translation on each side" do
    n = Node.root.children.create!(:slug => "diff_locale_test")
    d = find_or_create_draft(n, @user1)
    Globalize.with_locale(:en) { d.update!(:title => "Old English") }
    d.save!
    n.publish_draft!

    d2 = find_or_create_draft(n, @user1)
    Globalize.with_locale(:en) { d2.update!(:title => "New English") }
    d2.save!

    diff = d2.diff_against(n.head, :locale => :en)

    assert_match "<del>Old</del>", diff[:title]
    assert_match "<ins>New</ins>", diff[:title]
  end

  test "diff_against with an explicit locale ignores content in other locales entirely" do
    n = Node.root.children.create!(:slug => "diff_locale_isolation_test")
    d = find_or_create_draft(n, @user1)
    d.save!
    n.publish_draft!

    d2 = find_or_create_draft(n, @user1)
    Globalize.with_locale(:de) { d2.update!(:title => "Nur Deutsch geändert") }
    d2.save!

    diff = d2.diff_against(n.head, :locale => :en)

    assert_no_match(/Deutsch/, diff[:title])
  end

  test "locale_diff_summary flags a locale that only exists on one side as changed" do
    n = Node.root.children.create!(:slug => "diff_locale_summary_test")
    d = find_or_create_draft(n, @user1)
    d.save!
    n.publish_draft!

    d2 = find_or_create_draft(n, @user1)
    Globalize.with_locale(:en) { d2.update!(:title => "New English translation") }
    d2.save!

    summary = d2.locale_diff_summary(n.head)
    en_entry = summary.find { |s| s[:locale] == :en }

    assert en_entry[:changed]
    refute en_entry[:exists_there]
  end

  test "aggregate ignores order_by values outside the allowlist" do
    sql = Page.aggregate(:order_by => "pages.id; DROP TABLE pages--").to_sql

    assert_not_includes sql, "DROP"
    assert_includes sql, "pages.id ASC"
  end

  test "aggregate accepts allowlisted order columns, bare or prefixed" do
    assert_includes Page.aggregate(:order_by => "published_at").to_sql,
                    "pages.published_at ASC"
    assert_includes Page.aggregate(:order_by => "pages.published_at").to_sql,
                    "pages.published_at ASC"
  end

  test "template_name rejects values not present in the template directory" do
    page = Page.create!(:title => "Template guard")

    page.template_name = "../../partials/_article"
    assert_not page.valid?

    page.template_name = "standard_template"
    assert page.valid?

    page.template_name = ""
    assert page.valid?
  end

  test "a stale legacy template_name does not block unrelated saves" do
    page = Page.create!(:title => "Stale template")
    page.update_column(:template_name, "long_deleted_template")

    page.reload
    assert page.update(:abstract => "still saveable")
  end

  test "an aggregate over a scoped tag ignores pages outside that subtree" do
    updates = Node.root.children.create!(:slug => "updates")
    inside  = updates.children.create!(:slug => "inside-post")
    outside = Node.root.children.create!(:slug => "outside-post")

    [inside, outside].each do |node|
      node.reload.draft.update!(:title => node.slug, :tag_list => "update")
      node.publish_draft!
    end

    names = Page.aggregate({ :tags => "update" }).map { |p| p.node.unique_name }
    assert_includes     names, "updates/inside-post"
    assert_not_includes names, "outside-post"
  end
end
