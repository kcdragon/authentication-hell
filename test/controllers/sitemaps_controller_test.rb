require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "sitemap is public and lists the public pages" do
    get sitemap_url

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match root_url, response.body
    assert_match acknowledgements_url, response.body
    assert_match new_session_url, response.body
    assert_match new_registration_url, response.body
  end
end
