require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "request log lines carry the signed-in user's id" do
    sign_in_as(users(:one))

    assert_equal users(:one).id, user_id_logged_for { get root_url }
  end

  test "request log lines have no user id when signed out" do
    assert_nil user_id_logged_for { get root_url }
  end

  private

  def user_id_logged_for(&request)
    payloads = []
    ActiveSupport::Notifications.subscribed(->(event) { payloads << event.payload }, "process_action.action_controller", &request)
    payloads.last.fetch(:user_id)
  end
end
