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
    # Admin session
    get "admin/login", to: "admin#new", as: :admin_login
    post "admin/login", to: "admin#create"
    delete "admin/logout", to: "admin#destroy", as: :admin_logout

    # Admin-managed groups (keeps URLs at /group/admin...)
    resources :groups, path: "admin", controller: "groups", as: :admin, only: [ :index, :show, :create, :update, :destroy ] do
      member do
        post "sub_groups", action: :create_sub_group
        delete "sub_groups/:sub_group_id", action: :destroy_sub_group, as: :sub_group
      end

      # Memberships page + membership actions
      resources :memberships, controller: "memberships", only: [ :index ], param: :membership_id do
        member do
          post :promote, action: :promote_member
          post :demote, action: :demote_member
          delete :revoke, action: :revoke_membership
        end
      end

      # Membership request actions (join requests + invites)
      resources :membership_requests, controller: "memberships", only: [], param: :request_id do
        member do
          post :accept, action: :accept_membership_request
          post :reject, action: :reject_membership_request
          post :revoke_invite, action: :revoke_invite
        end
        collection do
          post :invite, action: :create_invite
        end
      end
    end
  end

  # Group pages (before catch-all)
  get "/g/:short_name", to: "group_pages#show", as: :group_page
  get "/g/:short_name/books", to: "group_pages#show"
  get "/g/:short_name/toys", to: "group_pages#show"
  # API routes
  namespace :api do
    resources :community_groups, only: [ :index, :show ] do
      collection do
        get "by_short_name/:short_name", to: "community_groups#by_short_name"
      end
      member do
        post :request_to_join
      end
    end

    get "my_groups", to: "community_groups#my_groups"
    get "my_groups/requests", to: "community_groups#my_group_requests"
    get "my_groups/invites", to: "community_groups#my_group_invites"
    post "my_groups/invites/:id/accept", to: "community_groups#accept_invite"
    patch "my_groups/memberships/:id", to: "community_groups#update_membership"
    delete "my_groups/memberships/:id", to: "community_groups#leave_group"
    delete "my_groups/requests/:id", to: "community_groups#cancel_join_request"

    resources :items, only: [ :index, :show, :create, :update, :destroy ] do
      collection do
        get :search
        get :my_items
        get :stats
      end
      member do
        post :track_view
      end
    end

    resources :users, only: [ :show, :update ] do
      collection do
        get :profile
      end
    end

    resources :item_requests, only: [ :index, :show, :create, :update, :destroy ] do
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
  get "*path", to: "home#index", constraints: ->(request) do
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

  root "home#index"
end
