class Totp::ChallengesController < ApplicationController
  PENDING_TIMEOUT = 10.minutes

  allow_unauthenticated_access
  before_action :require_pending_2fa
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

  private

  def require_pending_2fa
    @pending_user = User.find_by(id: session[:pending_2fa_user_id]) if session[:pending_2fa_user_id]

    unless @pending_user&.totp_enabled? && pending_2fa_fresh?
      clear_pending_2fa
      redirect_to new_session_path, alert: "Please sign in again."
    end
  end

  def pending_2fa_fresh?
    session[:pending_2fa_at].to_i >= PENDING_TIMEOUT.ago.to_i
  end

  def clear_pending_2fa
    session.delete(:pending_2fa_user_id)
    session.delete(:pending_2fa_at)
  end
end
