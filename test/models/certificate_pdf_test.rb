require "test_helper"

class CertificatePdfTest < ActiveSupport::TestCase
  test "renders a PDF document" do
    pdf = CertificatePdf.call(users(:one), verify_url: "https://authenticationhell.com/")

    assert pdf.start_with?("%PDF-"), "expected a PDF header"
    assert_operator pdf.bytesize, :>, 1000
  end

  test "renders even when the graduate achievement date is missing" do
    assert_nothing_raised do
      CertificatePdf.call(users(:two), verify_url: "https://example.com/")
    end
  end
end
