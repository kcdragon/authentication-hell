require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  # new_session_url is captured before the request: afterwards the url helpers
  # inherit the Avo engine's /admin SCRIPT_NAME and would mangle the path.
  test "redirects an unauthenticated visitor to sign in" do
    sign_in_url = new_session_url
    get "/admin"
    assert_response :redirect
    assert_equal sign_in_url, response.location
  end

  test "redirects a signed-in non-super-admin to sign in" do
    sign_in_url = new_session_url
    sign_in_as(users(:one))
    get "/admin"
    assert_response :redirect
    assert_equal sign_in_url, response.location
  end

  test "lets a super admin into the dashboard" do
    users(:one).update!(super_admin: true)
    sign_in_as(users(:one))
    get "/admin"
    follow_redirect!
    assert_response :success
  end

  test "lets a super admin manage game settings" do
    users(:one).update!(super_admin: true)
    sign_in_as(users(:one))
    get "/admin/resources/game_settings"
    assert_response :success
  end

  test "keeps a non-super-admin out of game settings" do
    sign_in_url = new_session_url
    sign_in_as(users(:one))
    get "/admin/resources/game_settings"
    assert_response :redirect
    assert_equal sign_in_url, response.location
  end
end
