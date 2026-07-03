class PasskeyRegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def create
    @user = User.new(registration_params)
    @user.validate

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
