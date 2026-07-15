require "test_helper"

class AttractControllerTest < ActionDispatch::IntegrationTest
  test "attract screen is public and invites visitors to play" do
    get attract_url

    assert_response :success
    assert_select "h1", /Authentication\s+Hell/
    assert_match "Scan to play", response.body
    assert_match "Mike Dalton", response.body
  end

  test "attract screen renders a scannable QR code" do
    get attract_url

    assert_select "div[role=img][aria-label=?] svg", "Scan to play Authentication Hell"
  end
end
