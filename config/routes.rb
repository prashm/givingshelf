Rails.application.routes.draw do
  # Admin routes
  namespace :admin do
    get "login", to: "sessions#new", as: :login
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy", as: :logout
  end

  ActiveAdmin.routes(self)
  # Handle Chrome devtools requests
  get "/.well-known/appspecific/com.chrome.devtools.json", to: proc { [ 404, {}, [ "" ] ] }

  # API routes
  namespace :api do
    resources :books, only: [ :index, :show, :create, :update, :destroy ] do
      collection do
        get :search
        get :my_books
        get :stats
      end
      member do
        post :track_view
        get :user_request
      end
    end

    resources :users, only: [ :show, :update ] do
      collection do
        get :profile
        get :my_requests
        get :received_requests
      end
    end

    resources :book_requests, only: [ :index, :show, :create, :update, :destroy ] do
      member do
        get :messages
      end
    end

    resources :location, only: [] do
      collection do
        get :detect_zip
        get :mapbox_token
      end
    end

    # Authentication routes
    post "/login", to: "sessions#create"
    post "/verify_otp", to: "sessions#verify_otp"
    post "/resend_otp", to: "sessions#resend_otp"
    delete "/logout", to: "sessions#destroy"
    post "/register", to: "registrations#create"
  end

  # Web routes
  resources :users, only: [ :new, :create ]
  resources :sessions, only: [ :new, :create, :destroy ]

  # Catch all for React routing - but exclude system paths
  get "*path", to: "books#index", constraints: ->(request) do
    !request.path.start_with?("/.well-known") &&
    !request.path.start_with?("/api") &&
    !request.path.start_with?("/assets") &&
    !request.path.start_with?("/packs") &&
    !request.path.start_with?("/admin") &&
    !request.path.start_with?("/favicon") &&
    !request.path.match?(/\.(ico|png|jpg|jpeg|gif|svg|webp|woff|woff2|ttf|eot)$/i)
  end

  root "books#index"
end
