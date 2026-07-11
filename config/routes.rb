Rails.application.routes.draw do
  mount_avo

  resource :session
  resource :user, only: %i[ show update ]
  resource :avatar, only: :destroy
  resource :registration, only: %i[ new create ]
  resource :passkey_registration, only: :create
  resource :email_confirmation, only: %i[ new create show ], param: :token
  resources :passwords, param: :token
  resource :password_change, only: %i[ show update ], controller: "users/passwords"

  resource :onboarding, only: :show, controller: "onboarding"
  namespace :onboarding do
    resource :password, only: :create
  end

  # Dev-only shortcut: signs in the first user. Returns 404 in every other environment.
  get "auto_sign_in" => "auto_sign_in#create", as: :auto_sign_in

  namespace :totp do
    resource :settings, only: %i[ show destroy ]
    resource :enrollment, only: %i[ new create ]
    resource :recovery_codes, only: %i[ create ]
    resource :challenge, only: %i[ new create ]
  end

  namespace :webauthn do
    resource  :settings, only: :show
    resources :credentials, only: %i[ create destroy ] do
      post :options, on: :collection
    end
    resource :authentication, only: :create do   # passwordless primary login
      post :options, on: :collection
    end
    resource :challenge, only: :create do        # passkey as a second factor
      post :options, on: :collection
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "game" => "games#show", as: :game
  get "game/frame" => "games#frame", as: :game_frame
  get "game/start" => "games#start", as: :game_start

  get "leaderboard" => "leaderboard#index", as: :leaderboard

  resource :certificate, only: :show do
    post :share
  end

  namespace :public do
    resources :certificates, only: :show, param: :token
  end

  namespace :api do
    post "bridge" => "bridge#create", as: :bridge
  end

  namespace :games do
    get  "totp/status"   => "totp_challenge#status",   as: :totp_status
    post "totp/start"    => "totp_challenge#start",    as: :totp_start
    post "totp/complete" => "totp_challenge#complete", as: :totp_complete

    get  "passkey/status"   => "passkey_challenge#status",   as: :passkey_status
    post "passkey/start"    => "passkey_challenge#start",    as: :passkey_start
    post "passkey/options"  => "passkey_challenge#options",  as: :passkey_options
    post "passkey/complete" => "passkey_challenge#complete", as: :passkey_complete

    get  "password/status"   => "password_challenge#status",   as: :password_status
    post "password/start"    => "password_challenge#start",    as: :password_start
    post "password/complete" => "password_challenge#complete", as: :password_complete

    get  "level_totp/status"   => "level_totp_challenge#status",   as: :level_totp_status
    post "level_totp/start"    => "level_totp_challenge#start",    as: :level_totp_start
    post "level_totp/register" => "level_totp_challenge#register", as: :level_totp_register
    post "level_totp/submit"   => "level_totp_challenge#submit",   as: :level_totp_submit

    get  "level_api_key/status" => "level_api_key_challenge#status", as: :level_api_key_status
    post "level_api_key/start"  => "level_api_key_challenge#start",  as: :level_api_key_start
    post "level_api_key/create" => "level_api_key_challenge#create", as: :level_api_key_create

    post "levels/complete" => "levels#complete", as: :levels_complete
    post "levels/playing"  => "levels#playing",  as: :levels_playing

    post "death" => "deaths#create", as: :death
    post "defeats" => "defeats#create", as: :defeats
  end

  namespace :editor do
    resources :levels, only: %i[ index show create ], param: :slug,
                       constraints: { slug: /[a-z0-9\-]+/ } do
      post :promote, on: :member
    end
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "acknowledgements" => "acknowledgements#show", as: :acknowledgements

  get "sitemap" => "sitemaps#show", as: :sitemap, defaults: { format: "xml" }

  # Defines the root path route ("/")
  root "home#show"
end
