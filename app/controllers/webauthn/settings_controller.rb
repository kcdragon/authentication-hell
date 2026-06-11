class Webauthn::SettingsController < ApplicationController
  def show
    @credentials = Current.user.webauthn_credentials.order(:created_at)
  end
end
