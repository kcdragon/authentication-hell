require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "landing page is public and introduces the game" do
    get root_url

    assert_response :success
    assert_select "h1", "Authentication Hell"
    assert_match "security course", response.body
    assert_match "RubyConf 2026", response.body
  end

  test "signed-out visitors get sign up / sign in calls to action" do
    get root_url

    assert_select "a[href=?]", new_registration_path
    assert_select "a[href=?]", new_session_path
  end

  test "signed-in visitors get a play call to action" do
    sign_in_as(users(:one))

    get root_url

    assert_select "a[href=?]", game_path
  end
end
