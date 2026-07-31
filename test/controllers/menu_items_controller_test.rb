require 'test_helper'

class MenuItemsControllerTest < ActionController::TestCase
  def create_menu_item(title = "Ausgangstitel")
    item = MenuItem.new(:path => "/menu_title_test")
    item.titles = { I18n.default_locale.to_s => title }
    item.save!
    item
  end

  test "updating stores a title per locale" do
    login_as :aaron
    item = create_menu_item

    patch :update, params: { :id => item.id,
      :menu_item => { :titles => { "de" => "Transparenz", "en" => "Transparency" } } }

    assert_equal "Transparenz",  item.reload.translations.find_by(:locale => "de").title
    assert_equal "Transparency", item.translations.find_by(:locale => "en").title
  end

  test "blanking a non-default title falls back to the default locale" do
    login_as :aaron
    item = create_menu_item
    patch :update, params: { :id => item.id,
      :menu_item => { :titles => { "de" => "Transparenz", "en" => "Transparency" } } }

    patch :update, params: { :id => item.id,
      :menu_item => { :titles => { "de" => "Transparenz", "en" => "" } } }

    item.reload
    assert_equal "Transparenz", Globalize.with_locale(:en) { item.title }
  end

  test "a blank default title is rejected" do
    login_as :aaron
    item = create_menu_item
    patch :update, params: { :id => item.id,
      :menu_item => { :titles => { "de" => "" } } }

    assert_response :success        # re-rendered :edit, not a redirect
    assert_not_equal "", item.reload.translations.find_by(:locale => "de").title
  end

  test "an editor without redaktion cannot reach the menu" do
    login_as :quentin
    get :index
    assert_redirected_to admin_path
    assert_equal I18n.t("flash.common.redaktion_required"), flash[:error]
  end
end
