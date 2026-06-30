module State
  def self.progress(args)
    started_at = args.state.level_started_at || args.state.tick_count
    limit = args.state.level.time_limit * 60
    ((args.state.tick_count - started_at) / limit.to_f).clamp(0.0, 1.0)
  end

  def self.intro_active?(args)
    args.state.started && args.state.level_intro_at &&
      (args.state.tick_count - args.state.level_intro_at) < LEVEL_INTRO_TICKS
  end

  def self.summary_active?(args)
    !args.state.level_summary.nil?
  end
end
