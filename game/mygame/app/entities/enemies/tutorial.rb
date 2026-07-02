# The tutorial's gate enemy: you can't stomp past it, so the only way through is the
# password re-auth. That lesson used to be a level-wide "melee off" flag; making it a
# distinct enemy keeps the rule with the thing it applies to. It looks and re-auths
# like a normal password padlock (inherits the render + :password auth) — it just
# refuses to be defeated by a stomp, always forcing the challenge instead.
class TutorialEnemy < PasswordEnemy
  def on_collision(other, args)
    return unless other.is_a?(Player)
    return if other.invincible?(args)

    @alive = false
    other.take_hit(args, @auth)
  end
end
