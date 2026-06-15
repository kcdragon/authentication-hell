require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "show requires authentication" do
    get game_url
    assert_redirected_to new_session_path
  end

  test "show renders the game page when signed in" do
    sign_in_as(@user)

    get game_url
    assert_response :success
  end

  test "me requires authentication" do
    get play_me_url
    assert_redirected_to new_session_path
  end

  test "me returns the current user's username and starting level as JSON" do
    sign_in_as(@user)

    get play_me_url
    assert_response :success
    assert_equal @user.username, response.parsed_body["username"]
    # No progress yet → starts on the tutorial (level 0).
    assert_equal 0, response.parsed_body["start_level"]
  end

  test "me's start_level resumes after the highest completed level" do
    @user.update!(highest_level_completed: 1)
    sign_in_as(@user)

    get play_me_url
    assert_equal 2, response.parsed_body["start_level"]
  end

  test "me's start_level honors a one-shot playlist selection, then clears it" do
    @user.update!(highest_level_completed: 2)
    sign_in_as(@user)

    # Clicking a watched level in the playlist reloads the frame, which stashes it.
    get game_frame_url(level: 0)
    assert_response :success

    get play_me_url
    assert_equal 0, response.parsed_body["start_level"]

    # One-shot: a subsequent boot falls back to progress (the frontier level).
    get play_me_url
    assert_equal 3, response.parsed_body["start_level"]
  end

  test "frame honors selecting the frontier (the next, not-yet-cleared level)" do
    @user.update!(highest_level_completed: 0)
    sign_in_as(@user)

    # current_level (frontier) is 1; the player can jump to it even un-cleared.
    get game_frame_url(level: 1)
    get play_me_url
    assert_equal 1, response.parsed_body["start_level"]
  end

  test "frame optimistically marks the selected level now playing and broadcasts" do
    @user.update!(highest_level_completed: 2)
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :playlist ]) do
      get game_frame_url(level: 0)
    end

    assert_equal 0, @user.reload.now_playing_level
    assert_equal 1, streams.size
  end

  test "frame does not touch now playing on a plain load with no selection" do
    @user.update!(highest_level_completed: 2, now_playing_level: 2)
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :playlist ]) do
      get game_frame_url
    end

    assert_equal 2, @user.reload.now_playing_level
    assert_empty streams
  end

  test "frame ignores a selection past the frontier" do
    @user.update!(highest_level_completed: 0)
    sign_in_as(@user)

    get game_frame_url(level: 2) # frontier is 1, so 2 is out of reach
    get play_me_url
    # Selection rejected → resumes at progress (level after the tutorial).
    assert_equal 1, response.parsed_body["start_level"]
  end
end
