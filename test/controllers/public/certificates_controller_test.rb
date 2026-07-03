require "test_helper"

class Public::CertificatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(highest_level_completed: GameLevel.all.last.number)
    @user.mark_certified! # a token only exists once the game is beaten, which stamps the date
  end

  test "show renders a public certificate for a valid token without signing in" do
    token = @user.ensure_certificate_token!

    get public_certificate_url(token)

    assert_response :success
    assert_select "h1", /#{@user.username} beat Authentication Hell/i
    assert_select "span", /Verified/i
  end

  test "show 404s on an unknown token" do
    get public_certificate_url("not-a-real-token")

    assert_response :not_found
  end
end
