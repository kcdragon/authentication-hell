module Collectable
  attr_reader :pickup_order
  attr_writer :alive

  def alive? = @alive

  def bob_offset(tick) = Math.sin(tick / 15.0) * self.class::BOB

  def on_collision(other, _args)
    return unless other.is_a?(Player)
    return unless @alive

    @alive = false
    @pickup_order = other.record_pickup
    collect(other)
  end
end
