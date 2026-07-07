class TotpEnemy < Enemy
  AUTH = :totp
  COLOR = { r: 90, g: 60, b: 160 }

  def render(frame, camera_x = 0, camera_y = 0)
    frame.outputs.sprites << { x: @x - camera_x + (@w - @h) / 2, y: @y - camera_y, w: @h, h: @h,
                              path: "sprites/enemies/totp.png" }
  end
end
