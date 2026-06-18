module Games::PasswordHelper
  # DOM id of a player's password re-auth toast, shared by the view that renders
  # the slot and the controller that broadcasts into / removes it.
  def password_challenge_toast_id(user)
    dom_id(user, :password_challenge)
  end

  # In development, the known db/seeds password so the challenge form can prefill
  # it and verifying is one click. Returns nil when prefills are disabled.
  def dev_password_prefill
    User::DEV_PASSWORD if dev_prefills_enabled?
  end
end
