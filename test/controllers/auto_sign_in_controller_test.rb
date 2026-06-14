require "test_helper"

class AutoSignInControllerTest < ActionDispatch::IntegrationTest
  test "signs in the first user in development" do
    assert_difference -> { User.first.sessions.count }, 1 do
      in_environment("development") { get auto_sign_in_path }
    end

    # No fixture user is fully set up, so the post-login nudge sends them to onboarding.
    assert_redirected_to onboarding_path
    assert cookies[:session_id]
  end

  test "returns 404 outside development" do
    get auto_sign_in_path

    assert_response :not_found
    assert_nil cookies[:session_id].presence
  end

  private
    def in_environment(name)
      original = Rails.env
      Rails.env = name
      yield
    ensure
      Rails.env = original
    end
end
