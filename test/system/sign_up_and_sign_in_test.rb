require "application_system_test_case"

class SignUpAndSignInTest < ApplicationSystemTestCase
  test "a new user can sign up, confirm their email, and sign in" do
    # Sign up
    visit new_registration_path

    fill_in "Choose a username", with: "newplayer"
    fill_in "Enter your email address", with: "newplayer@example.com"
    fill_in "Choose a password", with: "secretpassword"
    fill_in "Confirm your password", with: "secretpassword"
    click_on "Create account"

    # Lands back on sign in with a "check your email" notice and is NOT signed in yet.
    assert_current_path new_session_path
    assert_text "Check your email to confirm"

    user = User.find_by!(email_address: "newplayer@example.com")
    assert_not user.confirmed?

    # Sign-in is blocked until the email is confirmed.
    fill_in "Email", with: "newplayer@example.com"
    fill_in "Enter your password", with: "secretpassword"
    click_on "Sign in"
    assert_text "Please confirm your email first"

    # Confirm via the token the confirmation email would carry.
    token = user.generate_token_for(:email_confirmation)
    visit email_confirmation_path(token: token)
    assert_text "Email confirmed"
    assert user.reload.confirmed?

    # Now sign in succeeds and lands on the onboarding checklist (they only have a password).
    fill_in "Email", with: "newplayer@example.com"
    fill_in "Enter your password", with: "secretpassword"
    click_on "Sign in"

    assert_current_path onboarding_path
    # The h1 is uppercased by CSS (text-transform), so match case-insensitively.
    assert_text(/Secure your account/i)

    # The account menu is collapsed into a dropdown; open it to reach "Sign out".
    click_on "newplayer"
    assert_button "Sign out"
  end
end
