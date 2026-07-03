class Public::CertificatesController < ApplicationController
  allow_unauthenticated_access

  def show
    @user = User.find_by!(certificate_token: params[:token])
    @verify_url = public_certificate_url(@user.certificate_token)
  end
end
