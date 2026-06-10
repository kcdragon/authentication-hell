module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end

  # Enables TOTP 2FA for a user (encrypted secret + recovery codes) and returns the
  # raw secret so tests can compute valid codes with ROTP::TOTP.new(secret).now.
  def enable_2fa_for(user)
    secret = ROTP::Base32.random
    user.enable_totp!(secret)
    user.generate_recovery_codes!
    secret
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
