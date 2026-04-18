# frozen_string_literal: true

class Settings::TwoFactorsController < InertiaController
  before_action :set_user

  def show
    render inertia: "settings/two_factor/show", props: show_props
  end

  def new
    return redirect_to(settings_two_factor_path, notice: "Two-factor is already enabled.") if @user.totp_enabled?

    secret = User.generate_otp_secret
    session[:pending_otp_secret] = secret

    render inertia: "settings/two_factor/new", props: {
      qrSvg: qr_svg_for(secret),
      secret: secret,
      issuer: "Authentication Hell",
      email: @user.email
    }
  end

  def confirm
    secret = session[:pending_otp_secret]
    code = params[:code].to_s.strip

    if secret.blank?
      return redirect_to new_settings_two_factor_path, inertia: {errors: {code: "Setup expired. Start again."}}
    end

    unless @user.verify_otp(code, secret: secret)
      return render inertia: "settings/two_factor/new", props: {
        qrSvg: qr_svg_for(secret),
        secret: secret,
        issuer: "Authentication Hell",
        email: @user.email,
        errors: {code: "That code didn't match. Try the next one your app shows."}
      }
    end

    recovery_codes = nil
    User.transaction do
      @user.otp_secret = secret
      @user.otp_enabled_at = Time.current
      recovery_codes = @user.generate_recovery_codes!
      @user.save!
    end

    session.delete(:pending_otp_secret)
    flash.now[:notice] = "Two-factor authentication is now enabled."

    render inertia: "settings/two_factor/show",
      props: show_props.merge(recoveryCodes: recovery_codes)
  end

  def destroy
    @user.password_challenge = params[:password_challenge].to_s
    if @user.valid?
      @user.disable_two_factor!
      redirect_to settings_two_factor_path, notice: "Two-factor authentication disabled."
    else
      redirect_to settings_two_factor_path, inertia: {errors: @user.errors}
    end
  end

  private

  def set_user
    @user = Current.user
  end

  def show_props
    {
      totpEnabled: @user.totp_enabled?,
      enabledAt: @user.otp_enabled_at&.iso8601
    }
  end

  def qr_svg_for(secret)
    uri = ROTP::TOTP.new(secret, issuer: "Authentication Hell").provisioning_uri(@user.email)
    RQRCode::QRCode.new(uri).as_svg(module_size: 4, standalone: true, use_path: true)
  end
end
