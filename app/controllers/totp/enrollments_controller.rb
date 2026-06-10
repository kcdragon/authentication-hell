class Totp::EnrollmentsController < ApplicationController
  before_action :redirect_if_already_enabled

  def new
    @secret = session[:totp_setup_secret] ||= ROTP::Base32.random
    @provisioning_uri = ROTP::TOTP.new(@secret, issuer: User::TOTP_ISSUER).provisioning_uri(Current.user.email_address)
  end

  # Confirm enrollment by verifying a code against the candidate secret held in the
  # session, then persist the secret and generate recovery codes (shown once).
  def create
    secret = session[:totp_setup_secret]

    if secret.present? && ROTP::TOTP.new(secret).verify(params[:code].to_s.strip, drift_behind: 15)
      Current.user.enable_totp!(secret)
      @recovery_codes = Current.user.generate_recovery_codes!
      session.delete(:totp_setup_secret)
      render :recovery_codes
    else
      redirect_to new_totp_enrollment_path, alert: "That code was incorrect. Try again."
    end
  end

  private

  def redirect_if_already_enabled
    redirect_to totp_settings_path, notice: "Two-factor authentication is already enabled." if Current.user.totp_enabled?
  end
end
