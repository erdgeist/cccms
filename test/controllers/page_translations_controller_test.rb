require 'test_helper'

class PageTranslationsControllerTest < ActionController::TestCase
  test "update creates a first-time translation on a fresh draft, leaving head untouched" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "translations_create_test")
    Globalize.with_locale(:de) { node.draft.update!(:title => "Deutscher Titel") }
    node.publish_draft!
    node.lock_for_editing!(users(:quentin))

    patch :update, params: { :node_id => node.id, :translation_locale => "en", :page => { :title => "English Title" } }

    node.reload
    assert_not_nil node.draft
    assert_includes node.draft.translated_locales, :en
    assert_not_includes node.head.translated_locales, :en
  end

  test "no route exists for the default locale under the translations resource" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "translations_route_constraint_test")

    assert_raises(ActionController::UrlGenerationError) do
      patch :update, params: { :node_id => node.id, :translation_locale => "de", :page => { :title => "x" } }
    end
  end

  test "update with Save + Unlock + Exit unlocks the node and redirects to nodes#show" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "translations_exit_test")
    node.lock_for_editing!(users(:quentin))

    patch :update, params: { :node_id => node.id, :translation_locale => "en", :page => { :title => "x" }, :unlock_exit => "1" }

    assert_nil node.reload.lock_owner
    assert_redirected_to node_path(node)
  end

  test "update saves the translation onto the draft" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "translations_update_test")
    Globalize.with_locale(:en) { node.draft.update!(:title => "Original") }
    node.lock_for_editing!(users(:quentin))

    patch :update, params: { :node_id => node.id, :translation_locale => "en", :page => { :title => "Revised" } }

    assert_equal "Revised", Globalize.with_locale(:en) { node.draft.reload.title }
  end

  test "destroy refuses to remove the only remaining translation" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "translations_destroy_last_test")
    Globalize.with_locale(:en) { node.draft.update!(:title => "Only translation") }
    node.draft.translations.where(:locale => :de).delete_all

    delete :destroy, params: { :node_id => node.id, :translation_locale => "en" }

    assert_equal I18n.t("flash.page_translations.last_translation"), flash[:error]
  end

  test "destroy is a safe no-op, not a false success, when the translation doesn't exist" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "translations_destroy_missing_test")

    delete :destroy, params: { :node_id => node.id, :translation_locale => "en" }

    assert_equal I18n.t("flash.page_translations.none_to_remove", :lang => "EN"), flash[:error]
  end

  test "autosave writes the translation without creating a new revision or touching the draft" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "translations_autosave_test")
    node.publish_draft!
    node.lock_for_editing!(users(:quentin))
    page_count_before = node.pages.count

    put :autosave, params: { :node_id => node.id, :translation_locale => "en", :page => { :title => "in progress" } }

    assert_response :success
    node.reload
    assert_not_nil node.autosave
    assert_equal page_count_before, node.pages.count
    assert_equal "in progress", Globalize.with_locale(:en) { node.autosave.title }
  end

  test "destroy removes the translation, logs nothing, and redirects" do
    login_as :quentin
    node = Node.root.children.create!(:slug => "translation_destroy_log_test")
    Globalize.with_locale(:en) { node.draft.update!(:title => "English title") }

    assert_no_difference "NodeAction.count" do
      delete :destroy, params: { :node_id => node.id, :translation_locale => "en" }
    end

    assert_redirected_to node_path(node)
  end
end
