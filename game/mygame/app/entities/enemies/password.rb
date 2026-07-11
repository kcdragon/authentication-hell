class PasswordEnemy < Enemy
  AUTH = :password
  KIND = "password"
  COLOR = { r: 200, g: 140, b: 40 }

  def render(frame, camera_x = 0, camera_y = 0)
    frame.outputs.sprites << { x: @x - camera_x + (@w - @h) / 2, y: @y - camera_y, w: @h, h: @h,
                              path: "sprites/enemies/password.png" }
  end
end
