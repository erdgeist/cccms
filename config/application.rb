Cccm::Application.routes.draw do
  match 'locale' => '#index', :as => :filter
  match '/' => 'content#render_page', :page_path => ["home"], :locale => 'de'
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

  match '/logout' => 'sessions#destroy', :as => :logout
  match '/login' => 'sessions#new', :as => :login
  match 'admin/search' => 'admin#search', :as => :admin_search
  match 'search' => 'search#index', :as => :search
  resources :users
  resources :menu_items do
  
    member do
  post :sort
  end
  
  end

  resource :session
  match 'rss/:action' => 'rss#index', :as => :rss
  match 'rss/:action.:format' => 'rss#index', :as => :rss
  match '/:controller(/:action(/:id))'
  match 'galleries/*page_path' => 'content#render_gallery'
  match '/*page_path' => 'content#render_page', :as => :content
end

# Configure sensitive parameters which will be filtered from the log file.
config.filter_parameters += [:password, :password_confirmation]
