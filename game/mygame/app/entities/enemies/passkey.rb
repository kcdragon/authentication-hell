class PasskeyEnemy < Enemy
  AUTH = :passkey
  COLOR = { r: 60, g: 120, b: 200 }

  def render(args, camera_x = 0)
    args.outputs.sprites << { x: @x - camera_x + (@w - @h) / 2, y: @y, w: @h, h: @h,
                              path: "sprites/enemies/passkey.png" }
  end
end
