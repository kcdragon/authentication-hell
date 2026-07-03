require "application_system_test_case"

class SignUpAndSignInTest < ApplicationSystemTestCase
  test "a new user can sign up, confirm their email, and sign in" do
    visit new_registration_path

    fill_in "Choose a username", with: "newplayer"
    fill_in "Enter your email address", with: "newplayer@example.com"
    fill_in "Choose a password", with: "secretpassword"
    fill_in "Confirm your password", with: "secretpassword"
    click_on "Create account"

    assert_current_path new_session_path
    assert_text "Check your email to confirm"

    user = User.find_by!(email_address: "newplayer@example.com")
    assert_not user.confirmed?

    fill_in "Email", with: "newplayer@example.com"
    fill_in "Enter your password", with: "secretpassword"
    click_on "Sign in"
    assert_text "Please confirm your email first"

    token = user.generate_token_for(:email_confirmation)
    visit email_confirmation_path(token: token)
    assert_text "Email confirmed"
    assert user.reload.confirmed?

    fill_in "Email", with: "newplayer@example.com"
    fill_in "Enter your password", with: "secretpassword"
    click_on "Sign in"

    assert_current_path onboarding_path
    # The h1 is uppercased by CSS (text-transform), so match case-insensitively.
    assert_text(/Security/i)

    click_on "newplayer"
    assert_button "Sign out"
  end
end
