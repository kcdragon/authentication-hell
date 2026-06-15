# The password enemy: rendered as a padlock icon (sprites/enemies/password.png).
# The art is square, so it's drawn as a square sized to the body height and
# centered horizontally over the narrower body footprint. Walking into it
# triggers the password re-auth flow.
class PasswordEnemy < Enemy
  AUTH = :password
  COLOR = { r: 200, g: 140, b: 40 } # amber

  def render(args, camera_x = 0)
    args.outputs.sprites << { x: @x - camera_x + (@w - @h) / 2, y: @y, w: @h, h: @h,
                              path: "sprites/enemies/password.png" }
  end
end
