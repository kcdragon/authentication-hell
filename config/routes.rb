Rails.application.routes.draw do
  resource :session
  resource :user, only: %i[ show update ]
  resource :avatar, only: :destroy
  resource :registration, only: %i[ new create ]
  resource :passkey_registration, only: :create
  resource :email_confirmation, only: %i[ new create show ], param: :token
  resources :passwords, param: :token

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

  # The DragonRuby game lives at /game (games#show). /play/me is a small JSON
  # endpoint the running game fetches to greet the current user by name.
  get "game" => "games#show", as: :game
  get "play/me" => "games#me", as: :play_me

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
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#show"
end
