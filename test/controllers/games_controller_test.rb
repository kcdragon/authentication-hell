require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

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

  test "show surfaces the certificate claim toast once the game is beaten" do
    @user.update!(highest_level_completed: GameLevel.all.last.number)
    sign_in_as(@user)

    get game_url
    assert_response :success
    assert_match certificate_path, response.body
    assert_match "Claim your certificate", response.body
  end

  test "show hides the certificate claim toast until the game is beaten" do
    sign_in_as(@user)

    get game_url
    assert_response :success
    assert_no_match(/Claim your certificate/, response.body)
  end

  test "start requires authentication" do
    get game_start_url
    assert_redirected_to new_session_path
  end

  test "start returns the starting level as JSON" do
    sign_in_as(@user)

    get game_start_url
    assert_response :success
    assert_equal 0, response.parsed_body["start_level"]
  end

  test "start marks the resolved level now playing and broadcasts" do
    @user.update!(highest_level_completed: 1)
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :playlist ]) do
      get game_start_url
    end

    assert_equal 2, response.parsed_body["start_level"]
    assert_equal 2, @user.reload.now_playing_level
    assert_equal 1, streams.size
  end

  test "start's start_level resumes after the highest completed level" do
    @user.update!(highest_level_completed: 1)
    sign_in_as(@user)

    get game_start_url
    assert_equal 2, response.parsed_body["start_level"]
  end

  test "start's start_level honors a one-shot playlist selection, then clears it" do
    @user.update!(highest_level_completed: GameLevel.all.last.number)
    sign_in_as(@user)

    get game_frame_url(level: 0)
    assert_response :success

    get game_start_url
    assert_equal 0, response.parsed_body["start_level"]

    get game_start_url
    assert_equal GameLevel.all.last.number, response.parsed_body["start_level"]
  end

  test "frame honors selecting the frontier (the next, not-yet-cleared level)" do
    @user.update!(highest_level_completed: 0)
    sign_in_as(@user)

    get game_frame_url(level: 1)
    get game_start_url
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

  test "starting the run wipes the permanent toasts so a stale challenge can't linger" do
    sign_in_as(@user)
    post games_level_totp_start_url

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      get game_start_url
    end

    assert(streams.any? { |s| s["action"] == "update" && s["target"] == Game::Toasts::PERMANENT_CONTAINER },
      "expected the permanent toasts to be wiped when the run starts")
  end

  test "selecting a level wipes the permanent toasts so a stale challenge can't linger" do
    @user.update!(highest_level_completed: GameLevel.all.last.number)
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      get game_frame_url(level: 0)
    end

    assert(streams.any? { |s| s["action"] == "update" && s["target"] == Game::Toasts::PERMANENT_CONTAINER },
      "expected the permanent toasts to be wiped when selecting a level")
  end

  test "a plain frame load leaves the certificate toast in place" do
    @user.update!(highest_level_completed: GameLevel.all.last.number)
    sign_in_as(@user)

    streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
      get game_frame_url
    end

    assert_empty streams
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

  test "frame honors an out-of-frontier jump in development" do
    @user.update!(highest_level_completed: 0)
    sign_in_as(@user)

    in_env("development") { get game_frame_url(level: 2) }
    get game_start_url
    assert_equal 2, response.parsed_body["start_level"]
  end

  test "frame ignores an unknown level and leaves progress untouched" do
    @user.update!(highest_level_completed: 0, now_playing_level: 0)
    sign_in_as(@user)

    get game_frame_url(level: 99)
    assert_equal 0, @user.reload.now_playing_level
    get game_start_url
    assert_equal 1, response.parsed_body["start_level"]
  end

  test "frame still honors an in-frontier selection in production" do
    @user.update!(highest_level_completed: 1)
    sign_in_as(@user)

    in_env("production") { get game_frame_url(level: 1) }
    assert_equal 1, @user.reload.now_playing_level
    get game_start_url
    assert_equal 1, response.parsed_body["start_level"]
  end

  test "frame blocks an out-of-frontier jump in production" do
    @user.update!(highest_level_completed: 0, now_playing_level: 0)
    sign_in_as(@user)

    in_env("production") { get game_frame_url(level: 2) }
    assert_equal 0, @user.reload.now_playing_level
    get game_start_url
    assert_equal 1, response.parsed_body["start_level"]
  end

  test "show forwards the level param into the iframe src" do
    sign_in_as(@user)

    get game_url(level: 2)
    assert_response :success
    assert_match %r{/game/frame\?level=2}, response.body
  end

  test "start enqueues the achievement-awarding job with the current time" do
    sign_in_as(@user)

    travel_to Time.utc(2026, 7, 15, 12, 0) do
      assert_enqueued_with(job: AwardActiveAchievementsJob, args: [ @user, Time.current ]) do
        get game_start_url
      end
    end
  end

  test "playing before RubyConf awards the beta_tester achievement" do
    sign_in_as(@user)

    travel_to Time.utc(2026, 6, 21) do
      perform_enqueued_jobs { get game_start_url }
    end
    assert @user.earned?(:beta_tester)
  end

  test "playing during RubyConf awards only the attendee achievement" do
    sign_in_as(@user)

    noon_utc_still_july_15_in_pacific = Time.utc(2026, 7, 15, 12, 0)
    travel_to noon_utc_still_july_15_in_pacific do
      perform_enqueued_jobs { get game_start_url }
    end
    assert @user.earned?(:rubyconf_attendee)
    assert_not @user.earned?(:rubyconf_talk)
  end

  test "playing during the talk awards both attendee and talk" do
    sign_in_as(@user)

    eleven_thirty_pdt_on_talk_day = Time.utc(2026, 7, 16, 18, 30)
    travel_to eleven_thirty_pdt_on_talk_day do
      perform_enqueued_jobs { get game_start_url }
    end
    assert @user.earned?(:rubyconf_attendee)
    assert @user.earned?(:rubyconf_talk)
  end

  test "playing outside every window awards no event achievement" do
    sign_in_as(@user)

    travel_to Time.utc(2026, 8, 1) do
      assert_no_difference -> { @user.earned_achievements.count } do
        perform_enqueued_jobs { get game_start_url }
      end
    end
  end

  private

  def in_env(name)
    original = Rails.env
    Rails.env = name
    yield
  ensure
    Rails.env = original
  end
end
