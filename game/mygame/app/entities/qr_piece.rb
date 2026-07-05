class QrPiece
  include Collectable

  SIZE = 44
  LIFT = 40
  BOB = 6
  BORDER = 3

  attr_accessor :x, :y, :w, :h
  attr_reader :index

  def initialize(x:, y:, index:)
    @x = x
    @y = y
    @w = SIZE
    @h = SIZE
    @index = index
    @alive = true
  end

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  def collect(_player) = nil

  # Sprites are generated with bin/build-qr-pieces
  def sprite_path = "sprites/ui/qr_piece_#{@index}.png"

  def render(frame, camera_x = 0)
    bob = bob_offset(frame.tick_count)
    left = @x - camera_x
    bottom = @y + bob
    frame.outputs.solids << { x: left - BORDER, y: bottom - BORDER,
                             w: SIZE + BORDER * 2, h: SIZE + BORDER * 2,
                             r: INK[0], g: INK[1], b: INK[2] }
    frame.outputs.sprites << { x: left, y: bottom, w: SIZE, h: SIZE, path: sprite_path }
  end
end
