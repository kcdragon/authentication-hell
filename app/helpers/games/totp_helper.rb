module Games::TotpHelper
  # DOM id of a player's re-auth toast, shared by the view that renders the slot
  # and the controller that broadcasts into / removes it.
  def totp_challenge_toast_id(user)
    dom_id(user, :totp_challenge)
  end
end
