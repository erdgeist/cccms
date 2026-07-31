Cccms::Application.routes.draw do

  # Handles bare locale root paths: /de and /en (without trailing slash).
  # Must live outside and before the scope because the scope's /*page_path
  # catch-all would otherwise consume these before the locale segment is
  # recognised. Replaces routing-filter's around_recognize hook which
  # handled this transparently.
  get '/:locale', to: 'content#render_page',
      defaults: { page_path: ['home'] },
      constraints: { locale: /de|en/ }

  post 'csp_reports' => 'csp_reports#create'

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

    resources :events do
      collection do
        get :without_node
      end
    end

    get  'pages/:id/preview',     to: 'pages#preview',     as: :preview_page

    get 'preview/:token', to: 'shared_previews#show', as: :shared_preview

    scope '/admin' do
      resources :assets

      resources :nodes do
        collection do
          get 'tags/:tags', action: :tags, as: :tags, constraints: { tags: /[^\/]+/ }
          get :parameterize_preview
          get :drafts
          get :mine
          get :chapters
          get :sitemap
          get :trashed
        end

        member do
          put :unlock
          put :publish
          put :generate_shared_preview
          put :revoke_shared_preview
          put :autosave
          put :revert
          put :trash
          put :restore_from_trash
        end

        resources :translations, controller: 'page_translations',
          param: :translation_locale,
          constraints: { translation_locale: /en/ },
          only: [:show, :edit, :update, :destroy] do
          member do
            put :autosave
          end
        end

        resources :related_assets, only: [:create, :destroy, :update] do
          collection do
            get :search
          end
        end

        resources :revisions do
          collection do
            post :diff
            get  :diff
          end
          member do
            put :restore
          end
        end
      end

      match ''                 => 'admin#index',            :as => :admin,                  :via => :get
      match 'search'           => 'admin#search',           :as => :admin_search,           :via => :get
      match 'menu_search'      => 'admin#menu_search',      :as => :admin_menu_search,      :via => :get
      match 'conventions'      => 'admin#conventions',      :as => :admin_conventions,      :via => :get
      match 'dashboard_search' => 'admin#dashboard_search', :as => :admin_dashboard_search, :via => :get
      match 'log'              => 'node_actions#index',     :as => :admin_log,              :via => :get
      match 'boom'             => 'admin#boom',             :as => :admin_boom,             :via => :get
    end

    match '/logout'      => 'sessions#destroy', :as => :logout,       :via => :delete
    match '/login'       => 'sessions#new',     :as => :login,        :via => :get
    match 'search'       => 'search#index',     :as => :search,       :via => :get

    resources :users, :except => :destroy do
      member do
        put :reset_otp
        put :deactivate
        put :reactivate
      end
    end
    resource :otp_enrollment, :only => [:show, :create, :update, :destroy]
    resource :otp_challenge, :only => [:new, :create]

    resources :menu_items, :except => :show do
      member do
        post :sort
        post :move_up
        post :move_down
      end
    end

    resource :session

    get  'rss/updates',         :to => 'rss#updates', :as => :rss,      :defaults => { :format => :xml }
    get  'rss/updates.:format', :to => 'rss#updates', :as => :rss_feed, :defaults => { :format => :xml },
           :constraints => { :format => /xml|rdf/ }
    get  'rss/tags/:tag/updates',         :to => 'rss#tag_updates', :as => :rss_tag, :defaults => { :format => :xml }
    get  'rss/tags/:tag/updates.:format', :to => 'rss#tag_updates', :as => :rss_tag_feed, :defaults => { :format => :xml },
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
