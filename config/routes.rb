Cccms::Application.routes.draw do
  filter :locale

  root :to => 'content#render_page', :page_path => ['home'], :locale => 'de'

  resources :assets
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

  match '/logout'      => 'sessions#destroy', :as => :logout
  match '/login'       => 'sessions#new',     :as => :login
  match 'admin/search' => 'admin#search',     :as => :admin_search
  match 'search'       => 'search#index',     :as => :search

  resources :users

  resources :menu_items do
    member do
      post :sort
    end
  end

  resource :session

  match 'rss/:action'          => 'rss#index', :as => :rss
  match 'rss/:action.:format'  => 'rss#index'

  match '/:controller(/:action(/:id))'
  match '/:controller(/:action(/:id.:format))'

  match 'galleries/*page_path' => 'content#render_gallery'
  match '/*page_path'          => 'content#render_page', :as => :content
end
