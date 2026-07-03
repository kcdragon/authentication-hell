require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  def image_upload
    fixture_file_upload(Rails.root.join("public/icon.png"), "image/png")
  end

  # A genuinely non-image file: Active Storage re-sniffs the bytes, so a mislabeled
  # image would just be re-identified as an image and pass.
  def non_image_upload
    fixture_file_upload(Rails.root.join("Gemfile"), "text/plain")
  end

  # A real PNG (so it sniffs as an image) padded past the size limit.
  def oversized_image_upload
    file = Tempfile.new([ "big", ".png" ], binmode: true)
    file.write(Rails.root.join("public/icon.png").binread)
    file.write("0" * User::AVATAR_MAX_SIZE)
    file.rewind
    fixture_file_upload(file.path, "image/png")
  end

  test "requires authentication" do
    get user_path
    assert_redirected_to new_session_path
  end

  test "show renders" do
    sign_in_as(@user)
    get user_path
    assert_response :success
  end

  test "show lists achievements as earned or locked" do
    @user.grant_achievement(:totp_survivor)
    sign_in_as(@user)

    get user_path

    assert_response :success
    assert_select "h2", text: "Achievements"
    assert_select "div", text: /Code Cracker/
    assert_select "span", text: /Locked/
  end

  test "show displays the player's current level" do
    @user.update!(highest_level_completed: 0)
    sign_in_as(@user)

    get user_path

    assert_response :success
    assert_select "h2", text: "Current level"
    assert_select "p", text: /Lv 1 · Password Complexity/
  end

  test "update attaches an avatar" do
    sign_in_as(@user)

    patch user_path, params: { user: { avatar: image_upload } }

    assert_redirected_to user_path
    assert @user.reload.avatar.attached?
  end

  test "update rejects a non-image avatar" do
    sign_in_as(@user)

    patch user_path, params: { user: { avatar: non_image_upload } }

    assert_response :unprocessable_entity
    assert_not @user.reload.avatar.attached?
  end

  test "update re-renders without blowing up when an oversized image is rejected" do
    sign_in_as(@user)

    patch user_path, params: { user: { avatar: oversized_image_upload } }

    assert_response :unprocessable_entity
    assert_not @user.reload.avatar.attached?
  end
end
