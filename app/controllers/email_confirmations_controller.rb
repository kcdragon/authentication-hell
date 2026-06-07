class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_email_confirmation_path, alert: "Try again later." }

  def new
  end

  def create
    if (user = User.find_by(email_address: params[:email_address])) && !user.confirmed?
      ConfirmationsMailer.confirm(user).deliver_later
    end

    redirect_to new_session_path, notice: "If that account exists and is unconfirmed, a confirmation email has been sent."
  end

  def show
    user = User.find_by_token_for!(:email_confirmation, params[:token])
    user.confirm!
    redirect_to new_session_path, notice: "Email confirmed. You can now sign in."
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_email_confirmation_path, alert: "That confirmation link is invalid or has expired. Request a new one below."
  end
end
