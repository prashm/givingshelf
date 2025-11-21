Rails.application.routes.draw do
  # Handle Chrome devtools requests
  get '/.well-known/appspecific/com.chrome.devtools.json', to: proc { [404, {}, ['']] }
  
  # API routes
  namespace :api do
    resources :books, only: [:index, :show, :create, :update, :destroy] do
      collection do
        get :search
        get :my_books
      end
    end
    
    resources :users, only: [:show, :update] do
      collection do
        get :profile
        get :my_requests
        get :received_requests
      end
    end
    
    resources :book_requests, only: [:create, :update, :destroy]
    
    # Authentication routes
    post '/login', to: 'sessions#create'
    post '/verify_otp', to: 'sessions#verify_otp'
    post '/resend_otp', to: 'sessions#resend_otp'
    delete '/logout', to: 'sessions#destroy'
    post '/register', to: 'registrations#create'
  end

  # Web routes
  resources :users, only: [:new, :create]
  
  # Catch all for React routing - but exclude system paths
  get '*path', to: 'books#index', constraints: ->(request) do
    !request.path.start_with?('/.well-known') && 
    !request.path.start_with?('/api') &&
    !request.path.start_with?('/assets') &&
    !request.path.start_with?('/packs')
  end
  
  root 'books#index'
end
