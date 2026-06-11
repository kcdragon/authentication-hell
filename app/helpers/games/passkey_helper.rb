module Games::PasskeyHelper
  def passkey_challenge_toast_id(user)
    dom_id(user, :passkey_challenge)
  end
end
