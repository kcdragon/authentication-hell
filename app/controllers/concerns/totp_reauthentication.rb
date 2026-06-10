# Shared re-confirmation for sensitive 2FA actions (disable, regenerate codes):
# accept either a current TOTP/recovery code or the account password.
module TotpReauthentication
  extend ActiveSupport::Concern

  private

  def reauthenticated?
    confirmed_by_code? || confirmed_by_password?
  end

  def confirmed_by_code?
    Current.user.verify_totp(params[:code]) || Current.user.consume_recovery_code(params[:code])
  end

  def confirmed_by_password?
    params[:password].present? &&
      User.authenticate_by(email_address: Current.user.email_address, password: params[:password])
  end
end
