module WebauthnCeremony
  extend ActiveSupport::Concern

  private

  def credential_param
    params.require(:credential).to_unsafe_h
  end

  def store_credential(user, webauthn_credential, nickname)
    user.webauthn_credentials.create!(
      external_id: webauthn_credential.id,
      public_key:  webauthn_credential.public_key,
      sign_count:  webauthn_credential.sign_count,
      nickname:    nickname
    )
  end
end
