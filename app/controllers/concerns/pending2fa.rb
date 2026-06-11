# Shared state for the post-password second-factor step. After a correct password,
# SessionsController parks the user id in the session and redirects to a challenge
# (TOTP code or passkey assertion); these helpers gate those challenge controllers.
module Pending2fa
  extend ActiveSupport::Concern

  PENDING_TIMEOUT = 10.minutes

  included do
    before_action :require_pending_2fa
  end

  private

  def require_pending_2fa
    @pending_user = User.find_by(id: session[:pending_2fa_user_id]) if session[:pending_2fa_user_id]

    unless @pending_user&.second_factor? && pending_2fa_fresh?
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
