require "test_helper"

class AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "requires authentication" do
    delete avatar_path
    assert_redirected_to new_session_path
  end

  test "destroy removes an attached avatar" do
    @user.avatar.attach(io: Rails.root.join("public/icon.png").open, filename: "icon.png", content_type: "image/png")
    sign_in_as(@user)

    perform_enqueued_jobs do
      delete avatar_path
    end

    assert_redirected_to user_path
    assert_not @user.reload.avatar.attached?
  end
end
