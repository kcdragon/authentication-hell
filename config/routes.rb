Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resource :email_confirmation, only: %i[ new create show ], param: :token
  resources :passwords, param: :token

  namespace :totp do
    resource :settings, only: %i[ show destroy ]
    resource :enrollment, only: %i[ new create ]
    resource :recovery_codes, only: %i[ create ]
    resource :challenge, only: %i[ new create ]
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

  namespace :games do
    get  "totp/status"   => "totp_challenge#status",   as: :totp_status
    post "totp/start"    => "totp_challenge#start",    as: :totp_start
    post "totp/complete" => "totp_challenge#complete", as: :totp_complete

    get  "passkey/status"   => "passkey_challenge#status",   as: :passkey_status
    post "passkey/start"    => "passkey_challenge#start",    as: :passkey_start
    post "passkey/complete" => "passkey_challenge#complete", as: :passkey_complete
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "games#show"
end
