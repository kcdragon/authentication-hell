module Games::TotpHelper
  def totp_challenge_toast_id(user)
    dom_id(user, :totp_challenge)
  end
end
