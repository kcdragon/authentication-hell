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

  desc "Upload each achievement image to gamestats.ai"
  task upload_achievement_images: :environment do
    abort "gamestats credentials not configured" unless Gamestats::Client.configured?

    achievements = Achievement.all.select(&:image?)
    total = achievements.size

    achievements.each.with_index(1) do |achievement, i|
      asset = Rails.application.assets.load_path.find(achievement.image_path)

      unless asset
        puts "[#{i}/#{total}] SKIP #{achievement.key}: no image at #{achievement.image_path}"
        next
      end

      begin
        Gamestats::Client.upload_achievement_image(
          achievement_name: achievement.key,
          image_path: asset.path.to_s
        )
        puts "[#{i}/#{total}] uploaded #{achievement.key}"
      rescue Gamestats::Client::Error => e
        puts "[#{i}/#{total}] FAILED #{achievement.key}: #{e.message}"
      end
    end
  end
end
