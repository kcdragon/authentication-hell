class AutoSignInController < ApplicationController
  allow_unauthenticated_access only: :create

  def create
    raise ActionController::RoutingError, "Not Found" unless Rails.env.development?

    user = User.first
    return redirect_to new_session_path, alert: "No users to sign in as." unless user

    start_new_session_for user
    redirect_to after_authentication_url
  end
end
