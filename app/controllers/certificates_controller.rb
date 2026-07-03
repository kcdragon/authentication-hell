# The "you beat Authentication Hell" certificate. #show and #share are the owner's
# (auth-gated, reachable only once the final level is cleared); #verify is a public,
# token-gated page anyone can view — the URL the QR and share links point at.
class CertificatesController < ApplicationController
  allow_unauthenticated_access only: :verify
  before_action :require_completed_game, except: :verify

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

  # Public proof of completion. Unguessable token ⇒ no enumeration; a token only exists
  # once its owner has beaten the game (cleared on progress reset), so it always points
  # at a real completion.
  def verify
    @user = User.find_by!(certificate_token: params[:token])
    @verify_url = certificate_verify_url(token: params[:token])
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

    GenerateCertificatePdfJob.perform_later(Current.user, verify_url)
    CertificatePdf.call(Current.user, verify_url: verify_url)
  end

  def verify_url
    certificate_verify_url(token: Current.user.ensure_certificate_token!)
  end

  def require_completed_game
    redirect_to game_path unless Current.user.beat_game?
  end
end
