# Shared pickup behavior: when the player walks into a collectable it retires, stamps
# its pickup order, and applies its own #collect effect to the collector.
module Collectable
  attr_reader :pickup_order
  attr_writer :alive

  def alive? = @alive

  def on_collision(other, _args)
    return unless other.is_a?(Player)
    return unless @alive

    @alive = false
    @pickup_order = other.record_pickup
    collect(other)
  end
end
