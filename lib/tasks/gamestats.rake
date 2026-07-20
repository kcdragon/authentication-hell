namespace :gamestats do
  desc "Re-send every earned achievement to gamestats.ai"
  task backfill_achievements: :environment do
    abort "gamestats credentials not configured" unless Gamestats::Client.configured?

    total = EarnedAchievement.count

    EarnedAchievement.includes(:user).find_each.with_index(1) do |earned, i|
      username = earned.user.username

      begin
        Gamestats::Client.achievement_event(
          player_username: username,
          achievement_name: earned.achievement_key,
          occurred_at: earned.created_at
        )
        puts "[#{i}/#{total}] sent #{username} / #{earned.achievement_key}"
      rescue Gamestats::Client::Error => e
        puts "[#{i}/#{total}] FAILED #{username} / #{earned.achievement_key}: #{e.message}"
      end
    end
  end
end
