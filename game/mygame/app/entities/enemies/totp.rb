# The TOTP enemy: rendered as a one-time-password phone icon
# (sprites/enemies/totp.png). The art is square, so it's drawn as a square sized
# to the body height and centered horizontally over the narrower body footprint.
# Walking into it triggers the TOTP code re-auth flow.
class TotpEnemy < Enemy
  AUTH = :totp
  COLOR = { r: 90, g: 60, b: 160 } # drives the purple challenge toast tint

  def render(args, camera_x = 0)
    args.outputs.sprites << { x: @x - camera_x + (@w - @h) / 2, y: @y, w: @h, h: @h,
                              path: "sprites/enemies/totp.png" }
  end
end
