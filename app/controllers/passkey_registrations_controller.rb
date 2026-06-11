class PasskeyRegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  # First step of a passwordless signup: validate the username/email, then stash them
  # (plus a fresh WebAuthn user handle) in the session and render the passkey ceremony
  # page. The account is created only once the passkey verifies
  # (Webauthn::CredentialsController), so we never persist a credential-less user.
  def create
    @user = User.new(registration_params)
    @user.validate # the "add a password or a passkey" base error is expected here

    if @user.errors.attribute_names.intersect?(%i[ username email_address ])
      @signup_method = "passkey"
      render "registrations/new", status: :unprocessable_entity
    else
      session[:passwordless_registration] = {
        "username" => @user.username,
        "email_address" => @user.email_address,
        "webauthn_id" => WebAuthn.generate_user_id
      }
    end
  end

  private
    def registration_params
      params.expect(user: [ :username, :email_address ])
    end
end
