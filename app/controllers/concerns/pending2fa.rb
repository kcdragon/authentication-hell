module Pending2fa
  extend ActiveSupport::Concern

  included do
    before_action :require_pending_2fa
  end

  private

  def require_pending_2fa
    @pending_user = User.find_by_token_for(:pending_2fa, session[:pending_2fa_token]) if session[:pending_2fa_token]

    unless @pending_user&.second_factor?
      clear_pending_2fa
      redirect_to new_session_path, alert: "Please sign in again."
    end
  end

  def clear_pending_2fa
    session.delete(:pending_2fa_token)
  end
end
