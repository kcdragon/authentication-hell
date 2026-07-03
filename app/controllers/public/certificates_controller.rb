# Public, token-gated proof of completion anyone can view — the URL the certificate's
# QR and share links point at. An unguessable token ⇒ no enumeration; a token only
# exists once its owner has beaten the game (cleared on progress reset), so it always
# points at a real completion.
class Public::CertificatesController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = User.find_by!(certificate_token: params[:token])
    @verify_url = public_certificate_url(@user.certificate_token)
  end
end
