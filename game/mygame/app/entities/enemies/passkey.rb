class PasskeyEnemy < Enemy
  AUTH = :passkey
  KIND = "passkey"
  COLOR = { r: 60, g: 120, b: 200 }

  def render(frame, camera_x = 0, camera_y = 0)
    frame.outputs.sprites << { x: @x - camera_x + (@w - @h) / 2, y: @y - camera_y, w: @h, h: @h,
                              path: "sprites/enemies/passkey.png" }
  end
end
