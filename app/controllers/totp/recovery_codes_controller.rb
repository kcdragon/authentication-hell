class Totp::RecoveryCodesController < ApplicationController
  include TotpReauthentication

  before_action :require_otp_enabled

  def create
    if reauthenticated?
      @recovery_codes = Current.user.generate_recovery_codes!
      render "totp/enrollments/recovery_codes"
    else
      redirect_to totp_settings_path, alert: "Confirm with a current code or your password to regenerate codes."
    end
  end

  private

  def require_otp_enabled
    redirect_to totp_settings_path unless Current.user.totp_enabled?
  end
end
