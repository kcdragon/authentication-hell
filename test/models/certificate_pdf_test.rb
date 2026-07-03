require "test_helper"

class CertificatePdfTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.mark_certified!
  end

  test "renders a PDF document" do
    pdf = CertificatePdf.call(@user, verify_url: "https://authenticationhell.com/")

    assert pdf.start_with?("%PDF-"), "expected a PDF header"
    assert_operator pdf.bytesize, :>, 1000
  end
end
