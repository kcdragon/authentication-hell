class Webauthn::CredentialsController < ApplicationController
  include WebauthnCeremony

  # options/create run in two contexts: a signed-in user adding a passkey, or a
  # passwordless signup attaching its first passkey (identified by a session handle,
  # before any account is persisted). destroy is always for the signed-in user.
  allow_unauthenticated_access only: %i[ options create ]
  before_action :set_enrolling_user, only: %i[ options create ]

  def options
    create_options = WebAuthn::Credential.options_for_create(
      user: {
        id: @enrolling_user.webauthn_id,
        name: @enrolling_user.email_address,
        display_name: @enrolling_user.username
      },
      exclude: @enrolling_user.webauthn_credentials.pluck(:external_id),
      authenticator_selection: { user_verification: "required", resident_key: "required" }
    )

    session[:webauthn_creation_challenge] = create_options.challenge
    render json: create_options
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_create(credential_param)
    webauthn_credential.verify(session.delete(:webauthn_creation_challenge))

    if Current.user
      store_credential(Current.user, webauthn_credential, params[:nickname])
      render json: { redirect: webauthn_settings_path }
    else
      complete_passwordless_registration(webauthn_credential)
    end
  rescue WebAuthn::Error, ActiveRecord::RecordInvalid
    render json: { error: "We couldn't register that passkey. Please try again." }, status: :unprocessable_entity
  end

  def destroy
    credential = Current.user.webauthn_credentials.find(params[:id])

    if Current.user.passwordless? && Current.user.webauthn_credentials.count <= 1
      redirect_to webauthn_settings_path, alert: "Add a password or another passkey before removing your last one."
    else
      credential.destroy
      redirect_to webauthn_settings_path, notice: "Passkey removed."
    end
  end

  private

  def set_enrolling_user
    resume_session # populate Current.session from the cookie (require_authentication is skipped here)

    @enrolling_user = Current.user || pending_registration_user
    head :unauthorized unless @enrolling_user
  end

  # An unsaved User carrying the username/email/handle stashed by RegistrationsController
  # during a passwordless signup, so we can build creation options before persisting.
  def pending_registration_user
    reg = session[:passwordless_registration]
    return unless reg

    User.new(username: reg["username"], email_address: reg["email_address"], webauthn_id: reg["webauthn_id"])
  end

  def complete_passwordless_registration(webauthn_credential)
    reg = session[:passwordless_registration]
    user = User.new(username: reg["username"], email_address: reg["email_address"], webauthn_id: reg["webauthn_id"])
    user.webauthn_credentials.build(
      external_id: webauthn_credential.id,
      public_key:  webauthn_credential.public_key,
      sign_count:  webauthn_credential.sign_count,
      nickname:    params[:nickname]
    )
    user.save!

    ConfirmationsMailer.confirm(user).deliver_later
    session.delete(:passwordless_registration)
    flash[:notice] = "Account created. Check your email to confirm before signing in."
    render json: { redirect: new_session_path }
  end
end
