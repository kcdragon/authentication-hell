module Gamestats::LevelProgression
  extend self

  GAME_PROGRESSION_TYPE = "game".freeze
  GAME_PROGRESSION_NAME = "Authentication Hell".freeze
  LEVEL_PROGRESSION_TYPE = "level".freeze

  def started(user, level)
    return unless Gamestats::Client.configured?

    occurred_at = Time.current

    enqueue(user, level_event(level,
      milestone_type_name: "started", milestone_name: "started",
      is_new_instance: true, time_elapsed: 0, occurred_at:))

    if level.number.zero?
      enqueue(user, game_event(
        milestone_type_name: "started", milestone_name: "game_started",
        is_new_instance: true, time_elapsed: 0, occurred_at:))
    end
  end

  def objective(user, level, time_elapsed)
    return unless Gamestats::Client.configured?
    return unless level.objective_name

    enqueue(user, level_event(level,
      milestone_type_name: "objective", milestone_name: level.objective_name,
      time_elapsed:, occurred_at: Time.current))
  end

  def completed(user, level, time_elapsed)
    return unless Gamestats::Client.configured?

    occurred_at = Time.current

    enqueue(user, level_event(level,
      milestone_type_name: "completed", milestone_name: "completed",
      time_elapsed:, occurred_at:))

    enqueue(user, game_event(
      milestone_type_name: "level_completed", milestone_name: level.name,
      time_elapsed: level.number, occurred_at:))
  end

  private

  def level_event(level, **attributes)
    { progression_type_name: LEVEL_PROGRESSION_TYPE, progression_name: level.name, **attributes }
  end

  def game_event(**attributes)
    { progression_type_name: GAME_PROGRESSION_TYPE, progression_name: GAME_PROGRESSION_NAME, **attributes }
  end

  def enqueue(user, attributes)
    SendProgressionEventJob.perform_later(user, attributes)
  end
end
