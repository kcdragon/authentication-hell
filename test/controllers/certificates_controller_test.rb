require "test_helper"

class CertificatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(highest_level_completed: GameLevel.all.last.number)
  end

  test "show requires authentication" do
    get certificate_url
    assert_redirected_to new_session_path
  end

  test "show renders the certificate for a player who beat the game" do
    sign_in_as(@user)

    get certificate_url

    assert_response :success
    assert_select "h1", /beat Authentication Hell/i
  end

  test "show sends players who haven't beaten the game back to the game" do
    @user.update!(highest_level_completed: GameLevel.graduation.number - 1)
    sign_in_as(@user)

    get certificate_url

    assert_redirected_to game_path
  end

  test "show streams a PDF download" do
    sign_in_as(@user)

    get certificate_url(format: :pdf, download: 1)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF-")
    assert_match(/attachment/, response.headers["Content-Disposition"])
  end

  test "show serves the cached PDF when one is attached and doesn't re-render" do
    @user.certificate_pdf.attach(
      io: StringIO.new("%PDF-cached"), filename: "c.pdf", content_type: "application/pdf")
    sign_in_as(@user)

    assert_no_enqueued_jobs only: GenerateCertificatePdfJob do
      get certificate_url(format: :pdf)
    end

    assert_equal "%PDF-cached", response.body
  end

  test "show renders on the fly and backfills the cache when none is attached" do
    sign_in_as(@user)

    assert_enqueued_with(job: GenerateCertificatePdfJob) do
      get certificate_url(format: :pdf)
    end

    assert response.body.start_with?("%PDF-")
  end

  test "the PDF is gated behind beating the game too" do
    @user.update!(highest_level_completed: nil)
    sign_in_as(@user)

    get certificate_url(format: :pdf)

    assert_redirected_to game_path
  end

  test "share awards the Influencer achievement and toasts it" do
    sign_in_as(@user)

    streams = nil
    assert_difference -> { @user.earned_achievements.count }, 1 do
      streams = capture_turbo_stream_broadcasts([ @user, :toasts ]) do
        post share_certificate_url
      end
    end

    assert_response :no_content
    assert @user.earned?(:social_sharer)
    assert(streams.any? { |s| s.to_html.include?("Achievement unlocked") })
  end

  test "sharing more than once does not re-award" do
    @user.grant_achievement(:social_sharer)
    sign_in_as(@user)

    assert_no_difference -> { @user.earned_achievements.count } do
      post share_certificate_url
    end
  end

  test "viewing the certificate mints the verification token" do
    assert_nil @user.certificate_token
    sign_in_as(@user)

    get certificate_url

    assert_predicate @user.reload.certificate_token, :present?
  end
end
