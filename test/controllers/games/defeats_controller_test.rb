require "test_helper"

class Games::DefeatsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "create requires authentication" do
    post games_defeats_url, params: { kind: "totp" }
    assert_redirected_to new_session_path
  end

  test "create counts a defeat for each known enemy kind" do
    sign_in_as(@user)

    GameStat::DEFEAT_KINDS.each do |kind|
      post games_defeats_url, params: { kind: kind }
      assert_response :no_content
      assert_equal 1, @user.game_stats.find_by(key: "defeat_#{kind}").count
    end
  end

  test "create reads the kind from the query string, as the WASM game sends it" do
    sign_in_as(@user)

    post games_defeats_url(kind: "passkey")

    assert_response :no_content
    assert_equal 1, @user.game_stats.find_by(key: "defeat_passkey").count
  end

  test "repeated defeats increment the counter" do
    sign_in_as(@user)

    2.times { post games_defeats_url, params: { kind: "totp" } }

    assert_equal 2, @user.game_stats.find_by(key: "defeat_totp").count
  end

  test "create rejects an unknown kind" do
    sign_in_as(@user)

    assert_no_difference -> { GameStat.count } do
      post games_defeats_url, params: { kind: "boss" }
    end
    assert_response :unprocessable_entity
  end

  test "create rejects a missing kind" do
    sign_in_as(@user)

    post games_defeats_url

    assert_response :unprocessable_entity
  end
end
