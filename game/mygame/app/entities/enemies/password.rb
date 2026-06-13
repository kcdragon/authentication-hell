# The password enemy: rendered as a giant asterisk (a masked-character nod)
# rather than a solid rectangle, with a hitbox inset to match the smaller glyph.
class PasswordEnemy < Enemy
  AUTH = :password
  COLOR = { r: 200, g: 140, b: 40 } # amber
  HITBOX_INSET = 0.2 # fraction trimmed off each side so the box hugs the glyph

  def hitbox
    inset_w = @w * HITBOX_INSET
    inset_h = @h * HITBOX_INSET
    { x: @x + inset_w, y: @y + inset_h, w: @w - inset_w * 2, h: @h - inset_h * 2 }
  end

  def render(args, camera_x = 0)
    args.outputs.labels << { x: @x - camera_x + @w / 2,
                             y: @y + @h / 2,
                             text: "*",
                             size_px: @h,
                             r: @r, g: @g, b: @b,
                             anchor_x: 0.5,
                             anchor_y: 0.5 }
  end
end
