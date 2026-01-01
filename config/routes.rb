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

  # Group admin routes (before catch-all)
  namespace :group do
    get "admin", to: "admin#index", as: :admin_index
    get "admin/login", to: "admin#new", as: :admin_login
    post "admin/login", to: "admin#create"
    delete "admin/logout", to: "admin#destroy", as: :admin_logout
    get "admin/:id", to: "admin#show", as: :admin_group
    post "admin", to: "admin#create_group"
    patch "admin/:id", to: "admin#update"
    post "admin/:id/sub_groups", to: "admin#create_sub_group", as: :admin_sub_groups
    delete "admin/:id/sub_groups/:sub_group_id", to: "admin#destroy_sub_group", as: :admin_sub_group
  end

  # Group pages (before catch-all)
  get "/g/:short_name", to: "group_pages#show", as: :group_page

  # API routes
  namespace :api do
    resources :community_groups, only: [ :show ] do
      collection do
        get "by_short_name/:short_name", to: "community_groups#by_short_name"
      end
      member do
        get :memberships
      end
    end

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
      member do
        patch :update_community_groups
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
  get "passwords/new", to: "passwords#new", as: :new_password
  post "passwords", to: "passwords#create", as: :passwords
  get "passwords/:token/edit", to: "passwords#edit", as: :edit_password
  put "passwords/:token", to: "passwords#update", as: :password
  patch "passwords/:token", to: "passwords#update"

  # Catch all for React routing - but exclude system paths
  get "*path", to: "books#index", constraints: ->(request) do
    !request.path.start_with?("/.well-known") &&
    !request.path.start_with?("/api") &&
    !request.path.start_with?("/assets") &&
    !request.path.start_with?("/packs") &&
    !request.path.start_with?("/admin") &&
    !request.path.start_with?("/group") &&
    !request.path.start_with?("/g/") &&
    !request.path.start_with?("/passwords") &&
    !request.path.start_with?("/favicon") &&
    !request.path.match?(/\.(ico|png|jpg|jpeg|gif|svg|webp|woff|woff2|ttf|eot)$/i)
  end

  root "books#index"
end
