# The "you beat Authentication Hell" certificate. Reachable only once the player has
# cleared the final level (otherwise back to the game). Serves an HTML page with
# social-share buttons and a true PDF download; #share grants the Influencer achievement.
class CertificatesController < ApplicationController
  before_action :require_completed_game

  def show
    respond_to do |format|
      format.html
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

  # Prefer the copy GenerateCertificatePdfJob cached when the player beat the game;
  # render on the fly (and backfill the cache) if it hasn't landed yet or predates
  # this feature.
  def certificate_pdf
    return Current.user.certificate_pdf.download if Current.user.certificate_pdf.attached?

    GenerateCertificatePdfJob.perform_later(Current.user, root_url)
    CertificatePdf.call(Current.user, verify_url: root_url)
  end

  def require_completed_game
    redirect_to game_path unless Current.user.beat_game?
  end
end
