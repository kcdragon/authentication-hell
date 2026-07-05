class Frame
  attr_reader :inputs, :outputs, :tick_count

  def initialize(inputs, outputs, tick_count)
    @inputs = inputs
    @outputs = outputs
    @tick_count = tick_count
  end
end
