# Renders the certificate PDF and caches it on the user so the download endpoint
# doesn't rebuild it on every request. Enqueued when the player beats the final level
# (and lazily by the endpoint if the cache is ever missing). `verify_url` is passed in
# because a job has no request to derive the host from.
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
