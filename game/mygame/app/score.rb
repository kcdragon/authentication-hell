# A level's score: 100 per enemy stomped, a time bonus that rewards a faster finish
# (more seconds left against LEVEL_TIME_LIMIT), and a bonus per heart still held at
# the exit. Pure math, no engine I/O, so it's unit-tested under plain MRI like the
# entities.
module Score
  KILL_POINTS = 100
  TIME_BONUS_PER_SECOND = 10
  HEART_BONUS = 250

  # mruby Integer/Integer returns a Float; .to_i truncates back to whole seconds
  # (the value is non-negative, so this floors) and is a no-op under MRI in tests.
  def self.seconds_remaining(ticks)
    ([ LEVEL_TIME_LIMIT * 60 - ticks, 0 ].max / 60).to_i
  end

  def self.for(kills:, ticks:, hearts:)
    kill_points = kills * KILL_POINTS
    time_bonus = seconds_remaining(ticks) * TIME_BONUS_PER_SECOND
    heart_bonus = hearts * HEART_BONUS
    { kills: kills, kill_points: kill_points, time_bonus: time_bonus,
      hearts: hearts, heart_bonus: heart_bonus,
      total: kill_points + time_bonus + heart_bonus }
  end
end
