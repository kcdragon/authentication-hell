class Totp::EnrollmentsController < ApplicationController
  before_action :redirect_if_already_enabled

  def new
    @secret = session[:totp_setup_secret] ||= Totp.generate_random_secret
    @provisioning_uri = Totp.new(@secret).provisioning_uri(Current.user.email_address)
  end

  def create
    secret = session[:totp_setup_secret]

    if secret.present? && Totp.new(secret).verify(params[:code])
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
