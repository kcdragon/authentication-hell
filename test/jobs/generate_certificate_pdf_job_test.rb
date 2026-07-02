require "test_helper"

class GenerateCertificatePdfJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @user.update!(highest_level_completed: GameLevel.all.last.number)
  end

  test "attaches a rendered certificate PDF to the user" do
    GenerateCertificatePdfJob.perform_now(@user, "https://authenticationhell.com/")

    assert @user.certificate_pdf.attached?
    assert_equal "application/pdf", @user.certificate_pdf.content_type
    assert @user.certificate_pdf.download.start_with?("%PDF-")
  end

  test "does nothing for a player who hasn't beaten the game" do
    @user.update!(highest_level_completed: nil)

    GenerateCertificatePdfJob.perform_now(@user, "https://authenticationhell.com/")

    assert_not @user.certificate_pdf.attached?
  end
end
