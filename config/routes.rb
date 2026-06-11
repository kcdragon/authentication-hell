Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resource :passkey_registration, only: :create
  resource :email_confirmation, only: %i[ new create show ], param: :token
  resources :passwords, param: :token

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

  # DragonRuby game page. The canvas + loader are rendered inline by GamesController
  # (layout "game" sets <base href="/game_assets/"> so the loader's relative assets,
  # which live in the static bundle at public/game_assets/, resolve correctly).
  get "play" => "games#show", as: :play
  get "play/me" => "games#me", as: :play_me

  # Game collision lock → TOTP re-auth (Games::TotpController).
  namespace :games do
    get  "totp/status"    => "totp#status",    as: :totp_status
    post "totp/collision" => "totp#collision", as: :totp_collision
    post "totp/unlock"    => "totp#unlock",    as: :totp_unlock
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "games#show"
end
