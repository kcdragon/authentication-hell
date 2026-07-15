class LevelCompletion < ApplicationRecord
  MAX_MS = 3_600_000

  belongs_to :user

  validates :best_ms, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_MS }

  def self.record(user, level_number, ms)
    return unless ms.is_a?(Integer) && ms.positive? && ms <= MAX_MS

    previous_best = where(user_id: user.id, level_number: level_number).pick(:best_ms)
    upsert(
      { user_id: user.id, level_number: level_number, best_ms: ms },
      unique_by: %i[ user_id level_number ],
      on_duplicate: Arel.sql(
        %(best_ms = MIN(best_ms, excluded.best_ms),
          updated_at = CASE WHEN excluded.best_ms < best_ms THEN CURRENT_TIMESTAMP ELSE updated_at END)
      )
    )
    ms if previous_best.nil? || ms < previous_best
  end
end
