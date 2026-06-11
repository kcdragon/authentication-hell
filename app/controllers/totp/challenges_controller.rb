class Totp::ChallengesController < ApplicationController
  include Pending2fa

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_totp_challenge_path, alert: "Try again later." }

  def new
  end

  def create
    if @pending_user.verify_totp(params[:code]) || @pending_user.consume_recovery_code(params[:code])
      clear_pending_2fa
      start_new_session_for @pending_user
      redirect_to after_authentication_url
    else
      redirect_to new_totp_challenge_path, alert: "Invalid code. Try again."
    end
  end
end
