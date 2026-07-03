class CertificatesController < ApplicationController
  before_action :require_completed_game
  before_action :ensure_certified, only: :show

  def show
    respond_to do |format|
      format.html { @verify_url = verify_url }
      format.pdf do
        send_data certificate_pdf,
          filename: "authentication-hell-certificate.pdf",
          type: "application/pdf",
          disposition: params[:download] ? "attachment" : "inline"
      end
    end
  end

  def share
    Achievement::Awarder.call(Current.user, :social_sharer)
    head :no_content
  end

  private

  def certificate_pdf
    return Current.user.certificate_pdf.download if Current.user.certificate_pdf.attached?

    GenerateCertificatePdfJob.perform_later(Current.user, verify_url)
    CertificatePdf.call(Current.user, verify_url: verify_url)
  end

  def verify_url
    public_certificate_url(Current.user.ensure_certificate_token!)
  end

  def ensure_certified
    Current.user.mark_certified!
  end

  def require_completed_game
    redirect_to game_path unless Current.user.beat_game?
  end
end
