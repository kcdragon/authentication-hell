class PasswordEnemy < Enemy
  AUTH = :password
  COLOR = { r: 200, g: 140, b: 40 }

  def render(args, camera_x = 0)
    args.outputs.sprites << { x: @x - camera_x + (@w - @h) / 2, y: @y, w: @h, h: @h,
                              path: "sprites/enemies/password.png" }
  end
end
