# The passkey enemy: rendered as a passkey icon (sprites/enemies/passkey.png).
# The art is square, so it's drawn as a square sized to the body height and
# centered horizontally over the narrower body footprint. Walking into it
# triggers the passkey re-auth flow.
class PasskeyEnemy < Enemy
  AUTH = :passkey
  COLOR = { r: 60, g: 120, b: 200 } # matches the icon's blue

  def render(args, camera_x = 0)
    args.outputs.sprites << { x: @x - camera_x + (@w - @h) / 2, y: @y, w: @h, h: @h,
                              path: "sprites/enemies/passkey.png" }
  end
end
