require "test_helper"

class Games::PasswordChallengeControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include Games::PasswordHelper

  setup { @user = users(:one) }

  test "start requires authentication" do
    post games_password_start_url
    assert_redirected_to new_session_path
  end

  test "start broadcasts the password re-auth toast and locks the player" do
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_password_start_url
    end

    assert_equal 1, streams.size
    broadcast = streams.first
    assert_equal "append", broadcast["action"]
    assert_equal Game::Toasts::PERMANENT_CONTAINER, broadcast["target"]
    assert_includes broadcast.to_html, "Re-authenticate with your password"

    assert_response :no_content

    get games_password_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "status requires authentication" do
    get games_password_status_url
    assert_redirected_to new_session_path
  end

  test "status reports unlocked until a collision locks the player" do
    sign_in_as(@user)

    get games_password_status_url
    assert_equal({ "locked" => false }, response.parsed_body)

    post games_password_start_url
    get games_password_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete requires authentication" do
    post games_password_complete_url
    assert_redirected_to new_session_path
  end

  test "complete with a valid password clears the lock" do
    sign_in_as(@user)
    post games_password_start_url

    post games_password_complete_url, params: { password: "password" }, as: :turbo_stream

    assert_response :success
    assert_match "turbo-stream", response.media_type
    assert_includes response.body, %(<turbo-stream action="remove" target="#{password_challenge_toast_id(@user)}">)
    assert_not_includes response.body, "Re-authenticate with your password"
    get games_password_status_url
    assert_equal({ "locked" => false }, response.parsed_body)
  end

  test "completing the challenge awards the survivor achievement and toasts it" do
    sign_in_as(@user)
    post games_password_start_url

    streams = nil
    assert_difference -> { @user.earned_achievements.count }, 1 do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
        post games_password_complete_url, params: { password: "password" }, as: :turbo_stream
      end
    end
    assert @user.earned?(:password_survivor)
    assert(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
  end

  test "completing again does not re-award or re-toast an already-earned achievement" do
    @user.grant_achievement(:password_survivor)
    sign_in_as(@user)
    post games_password_start_url

    streams = nil
    assert_no_difference -> { @user.earned_achievements.count } do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
        post games_password_complete_url, params: { password: "password" }, as: :turbo_stream
      end
    end
    assert_not(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
  end

  test "each completed challenge counts a password re-authentication" do
    sign_in_as(@user)

    2.times do
      post games_password_start_url
      post games_password_complete_url, params: { password: "password" }, as: :turbo_stream
    end

    assert_equal 2, @user.game_stats.find_by(key: "reauth_password").count
  end

  test "failing the challenge counts no re-authentication" do
    sign_in_as(@user)
    post games_password_start_url

    post games_password_complete_url, params: { password: "wrong" }, as: :turbo_stream

    assert_nil @user.game_stats.find_by(key: "reauth_password")
  end

  test "failing the challenge awards nothing" do
    sign_in_as(@user)
    post games_password_start_url

    assert_no_difference -> { @user.earned_achievements.count } do
      post games_password_complete_url, params: { password: "wrong" }, as: :turbo_stream
    end
  end

  test "complete with an invalid password keeps the player locked and shows an error" do
    sign_in_as(@user)
    post games_password_start_url

    post games_password_complete_url, params: { password: "wrong" }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "Invalid password. Try again."
    get games_password_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end

  test "complete cannot clear the lock for a passwordless player" do
    user = users(:passwordless)
    sign_in_as(user)
    post games_password_start_url

    post games_password_complete_url, params: { password: "password" }, as: :turbo_stream

    assert_response :success
    get games_password_status_url
    assert_equal({ "locked" => true }, response.parsed_body)
  end
end
