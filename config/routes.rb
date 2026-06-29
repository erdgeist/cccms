Cccms::Application.routes.draw do

  # Handles bare locale root paths: /de and /en (without trailing slash).
  # Must live outside and before the scope because the scope's /*page_path
  # catch-all would otherwise consume these before the locale segment is
  # recognised. Replaces routing-filter's around_recognize hook which
  # handled this transparently.
  get '/:locale', to: 'content#render_page',
      defaults: { page_path: ['home'] },
      constraints: { locale: /de|en/ }

  # All application routes are scoped under an optional two-letter locale
  # prefix: /de/... and /en/... Both forms are valid; the prefix is omitted
  # for the default locale (:de) in generated URLs via default_url_options
  # in ApplicationController. This replaces the routing-filter gem.
  #
  # The locale regex must be kept in sync with config/application.rb
  # (config.i18n.available_locales) and ApplicationController#set_locale.
  # Adding a new locale requires updating all three locations.
  scope '(:locale)', locale: /de|en/ do

    resources :tags
    resources :occurrences
    resources :events

    resources :pages do
      member do
        get :preview
        put :sort_images
      end
    end

    resources :nodes do
      member do
        put :unlock
        put :publish
      end

      resources :revisions do
        collection do
          post :diff
        end
        member do
          put :restore
        end
      end
    end

    scope '/admin' do
      resources :assets
    end

    match '/logout'      => 'sessions#destroy', :as => :logout,       :via => :delete
    match '/login'       => 'sessions#new',     :as => :login,        :via => :get
    match 'admin'        => 'admin#index',      :as => :admin,        :via => :get
    match 'admin/search' => 'admin#search',     :as => :admin_search, :via => :get
    match 'admin/menu_search' => 'admin#menu_search', :as => :admin_menu_search, :via => :get
    match 'search'       => 'search#index',     :as => :search,       :via => :get

    resources :users

    resources :menu_items do
      member do
        post :sort
      end
    end

    resource :session

    get  'rss/updates',         :to => 'rss#updates', :as => :rss
    get  'rss/updates.:format', :to => 'rss#updates', :as => :rss_feed,
           :constraints => { :format => /xml|rdf/ }
    get  'rss/recent_changes',  :to => 'rss#recent_changes'
    get  'rss/tags/:tag/updates',         :to => 'rss#tag_updates', :as => :rss_tag
    get  'rss/tags/:tag/updates.:format', :to => 'rss#tag_updates', :as => :rss_tag_feed,
           :constraints => { :format => /xml/ }

    match 'galleries/*page_path' => 'content#render_gallery', :via => :get
    match '/*page_path'          => 'content#render_page', :as => :content, :via => :get

    # Handles /de/ and /en/ (locale root with trailing slash).
    # The bare-slash case inside the scope is distinct from the /:locale
    # route above due to trailing slash handling in Rack/Rails routing.
    get '/', to: 'content#render_page', defaults: { page_path: ['home'] }

    # Handles / (no locale prefix — default locale :de).
    root to: 'content#render_page', defaults: { page_path: ['home'] }

  end

end
