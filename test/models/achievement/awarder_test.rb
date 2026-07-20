require "test_helper"

class Achievement::AwarderTest < ActiveJob::TestCase
  setup { @user = users(:one) }

  CREDENTIALS = { gamestats: { api_key: "test-key", account_id: 42 } }.freeze

  test "enqueues a gamestats event with the earn time on a fresh grant when configured" do
    with_credentials(CREDENTIALS) do
      Achievement::Awarder.call(@user, :graduate)

      earned = @user.earned_achievements.find_by!(achievement_key: "graduate")
      assert_enqueued_with(job: SendAchievementEventJob, args: [ @user, "graduate", earned.created_at ])
    end
  end

  test "does not enqueue on a duplicate grant" do
    with_credentials(CREDENTIALS) do
      Achievement::Awarder.call(@user, :graduate)

      assert_no_enqueued_jobs only: SendAchievementEventJob do
        Achievement::Awarder.call(@user, :graduate)
      end
    end
  end

  test "does not enqueue when gamestats is not configured" do
    with_credentials({}) do
      assert_no_enqueued_jobs only: SendAchievementEventJob do
        Achievement::Awarder.call(@user, :graduate)
      end
    end
  end

  private

  def with_credentials(hash)
    Rails.application.define_singleton_method(:credentials) { ActiveSupport::HashWithIndifferentAccess.new(hash) }
    yield
  ensure
    Rails.application.singleton_class.remove_method(:credentials)
  end
end
