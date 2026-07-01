module State
  def self.progress(args)
    args.state.level.progress(args.state.tick_count)
  end

  def self.intro_active?(args)
    args.state.started && args.state.level.intro_active?(args.state.tick_count)
  end

  def self.summary_active?(args)
    !args.state.level_summary.nil?
  end
end
