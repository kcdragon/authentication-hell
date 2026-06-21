module State
  def self.progress(args)
    started_at = args.state.level_started_at || args.state.tick_count
    ((args.state.tick_count - started_at) / (LEVEL_TIME_LIMIT * 60).to_f).clamp(0.0, 1.0)
  end

  def self.intro_active?(args)
    args.state.started && args.state.level_intro_at &&
      (args.state.tick_count - args.state.level_intro_at) < LEVEL_INTRO_TICKS
  end
end
