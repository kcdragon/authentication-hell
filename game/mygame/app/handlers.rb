module Handlers
  def self.caption_input(args)
    hit = args.inputs.mouse.click && args.inputs.mouse.point.inside_rect?(CC_BUTTON)
    args.state.captions_on = !args.state.captions_on if hit
    !!hit
  end
end
