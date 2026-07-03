class Totp::SettingsController < ApplicationController
  include TotpReauthentication

  def show
  end

  def destroy
    if reauthenticated?
      Current.user.disable_totp!
      redirect_to totp_settings_path, notice: "Two-factor authentication disabled."
    else
      redirect_to totp_settings_path, alert: "Confirm with a current code or your password to disable."
    end
  end
end
