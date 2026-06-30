require "test_helper"

class Games::DeathsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "create requires authentication" do
    post games_death_url
    assert_redirected_to new_session_path
  end

  test "create clears active challenges and broadcasts a toast wipe" do
    sign_in_as(@user)
    post games_totp_start_url
    post games_password_start_url

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      post games_death_url
    end

    assert_response :no_content

    assert_equal 2, streams.size
    clear, notice = streams
    assert_equal "update", clear["action"]
    assert_equal "toasts", clear["target"]

    assert_equal "append", notice["action"]
    assert_equal "toasts", notice["target"]
    assert_includes notice.to_html, "Video ended"

    get games_totp_status_url
    assert_equal({ "locked" => false }, response.parsed_body)
    get games_password_status_url
    assert_equal({ "locked" => false }, response.parsed_body)
  end
end
