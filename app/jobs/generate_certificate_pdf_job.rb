class GenerateCertificatePdfJob < ApplicationJob
  queue_as :default

  def perform(user, verify_url)
    return unless user.beat_game?

    pdf = CertificatePdf.call(user, verify_url: verify_url)
    user.certificate_pdf.attach(
      io: StringIO.new(pdf),
      filename: "authentication-hell-certificate.pdf",
      content_type: "application/pdf"
    )
  end
end
