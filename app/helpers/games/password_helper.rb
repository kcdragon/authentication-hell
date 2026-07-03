module Games::PasswordHelper
  def password_challenge_toast_id(user)
    dom_id(user, :password_challenge)
  end

  def dev_password_prefill
    User::DEV_PASSWORD if dev_prefills_enabled?
  end
end
