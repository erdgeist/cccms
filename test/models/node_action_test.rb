require "test_helper"

class NodeActionTest < ActiveSupport::TestCase

  # Standalone pages, no node -- same pattern autosave relies on.
  # Default-locale attributes are written pinned, never ambient.
  def build_page en: nil, **attrs
    page = Globalize.with_locale(I18n.default_locale) do
      Page.create!({ :title => "Titel" }.merge(attrs))
    end
    page.translations.create!({ :locale => "en" }.merge(en)) if en
    page.reload
  end

  test "first publish yields exactly the title pair, from nil" do
    diff = NodeAction.head_diff(nil, build_page(:title => "Erstausgabe"))

    assert_equal({ :title => { "from" => nil, "to" => "Erstausgabe" } }, diff)
  end

  test "title pair is always present, even when unchanged" do
    diff = NodeAction.head_diff(build_page, build_page)

    assert_equal "Titel", diff[:title]["from"]
    assert_equal "Titel", diff[:title]["to"]
  end

  test "author pair present only when the byline changed" do
    u1, u2 = users(:quentin), users(:aaron)

    assert_nil NodeAction.head_diff(build_page(:user => u1), build_page(:user => u1))[:author]

    changed = NodeAction.head_diff(build_page(:user => u1), build_page(:user => u2))
    assert_equal({ "from" => u1.login, "to" => u2.login }, changed[:author])
  end

  test "tags pair present only when the tag set changed" do
    old_page = build_page; old_page.tag_list = "alpha, beta";  old_page.save!
    new_page = build_page; new_page.tag_list = "beta, gamma"; new_page.save!

    diff = NodeAction.head_diff(old_page.reload, new_page.reload)
    assert_equal %w[alpha beta],  diff[:tags]["from"]
    assert_equal %w[beta gamma], diff[:tags]["to"]

    same = NodeAction.head_diff(old_page, old_page)
    assert_nil same[:tags]
  end

  test "template_changed flag only when true" do
    old_page = build_page(:template_name => "standard_template")

    assert NodeAction.head_diff(old_page, build_page(:template_name => "update"))[:template_changed]
    assert_nil NodeAction.head_diff(old_page, build_page(:template_name => "standard_template"))[:template_changed]
  end

  test "assets_changed flag when the attached set differs" do
    asset = Asset.create!(:name => "diff probe",
                          :upload_file_name    => "test_image.png",
                          :upload_content_type => "image/png",
                          :upload_file_size    => 49854,
                          :upload_updated_at   => Time.current)
    old_page, new_page = build_page, build_page
    new_page.related_assets.create!(:asset_id => asset.id, :position => 1)


    diff = NodeAction.head_diff(old_page, new_page.reload)
    assert diff[:assets_changed]
    assert_nil NodeAction.head_diff(old_page, old_page)[:assets_changed]
  end

  test "default-locale abstract and body changes become flags, only when true" do
    diff = NodeAction.head_diff(build_page(:abstract => "a"), build_page(:abstract => "b"))

    assert diff[:abstract_changed]
    assert_nil diff[:body_changed]
  end

  test "added locale carries status and the new title" do
    diff = NodeAction.head_diff(build_page, build_page(en: { :title => "English" }))

    entry = diff[:translation_diff]["en"]
    assert_equal "added", entry["status"]
    assert_equal({ "from" => nil, "to" => "English" }, entry["title"])
  end

  test "removed locale keeps the vanished title" do
    diff = NodeAction.head_diff(build_page(en: { :title => "English" }), build_page)

    entry = diff[:translation_diff]["en"]
    assert_equal "removed", entry["status"]
    assert_equal "English", entry["title"]["from"]
    assert_nil entry["title"]["to"]
  end

  test "changed locale carries only what actually differs" do
    old_page = build_page(en: { :title => "Same", :body => "old" })
    new_page = build_page(en: { :title => "Same", :body => "new" })

    entry = NodeAction.head_diff(old_page, new_page)[:translation_diff]["en"]
    assert_equal "changed", entry["status"]
    assert_nil entry["title"]
    assert entry["body_changed"]
    assert_nil entry["abstract_changed"]
  end

  test "untouched locales are absent; identical pages yield no translation_diff at all" do
    old_page = build_page(en: { :title => "Same" })
    new_page = build_page(en: { :title => "Same" })

    assert_nil NodeAction.head_diff(old_page, new_page)[:translation_diff]
  end
end
