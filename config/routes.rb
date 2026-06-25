Cccms::Application.routes.draw do
  filter :locale

  root :to => 'content#render_page', :page_path => ['home'], :locale => 'de'

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
  match 'search'       => 'search#index',     :as => :search,       :via => :get

  resources :users

  resources :menu_items do
    member do
      post :sort
    end
  end

  resource :session

  get  'rss/updates',          :to => 'rss#updates', :as => :rss
  get  'rss/updates.:format',  :to => 'rss#updates', :as => :rss_feed,
         :constraints => { :format => /xml|rdf/ }
  get  'rss/recent_changes',   :to => 'rss#recent_changes'

  match 'galleries/*page_path' => 'content#render_gallery', :via => :get
  match '/*page_path' => 'content#render_page', :as => :content, :via => :get
end
