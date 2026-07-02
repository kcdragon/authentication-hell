# The tutorial's gate enemy: you can't stomp past it, so the only way through is the
# password re-auth. Marking it non-stompable makes both sides do the right thing — the
# enemy survives a stomp long enough to force the hit, and the player re-auths instead
# of bouncing. It looks and authenticates like a normal password padlock (inherits the
# render + :password auth).
class TutorialEnemy < PasswordEnemy
  def stompable? = false
end
