class QrPiece < Pickup
  SIZE = 44
  LIFT = 40
  BORDER = 3

  attr_reader :index

  def initialize(x:, y:, index:)
    super(x: x, y: y)
    @index = index
  end

  # Sprites are generated with bin/build-qr-pieces
  def sprite_path = "sprites/ui/qr_piece_#{@index}.png"

  def render(frame, camera_x = 0, camera_y = 0)
    bob = bob_offset(frame.tick_count)
    left = @x - camera_x
    bottom = @y + bob - camera_y
    frame.outputs.sprites << { path: :solid, x: left - BORDER, y: bottom - BORDER,
                             w: SIZE + BORDER * 2, h: SIZE + BORDER * 2,
                             r: INK[0], g: INK[1], b: INK[2] }
    frame.outputs.sprites << { x: left, y: bottom, w: SIZE, h: SIZE, path: sprite_path }
  end
end
