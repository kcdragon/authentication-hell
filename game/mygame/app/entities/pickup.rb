class Pickup
  BOB = 6

  attr_accessor :x, :y, :w, :h
  attr_reader :pickup_order
  attr_writer :alive

  def initialize(x:, y:)
    @x = x
    @y = y
    @w = self.class::SIZE
    @h = self.class::SIZE
    @alive = true
  end

  def alive? = @alive

  def hitbox = { x: @x, y: @y, w: @w, h: @h }

  def collect(_player) = nil

  def on_collision(other, _frame)
    return unless other.is_a?(Player)
    return unless @alive

    @alive = false
    @pickup_order = other.record_pickup
    collect(other)
  end

  private

  def bob_offset(tick) = Math.sin(tick / 15.0) * self.class::BOB
end
