import { create } from "@github/webauthn-json"
import WebauthnCeremonyController from "lib/webauthn_ceremony_controller"

// Drives a passkey *registration* ceremony: fetch creation options from Rails, hand
// them to the authenticator via @github/webauthn-json, then POST the new credential
// back. Used on the settings "Add a passkey" form and passwordless signup.
export default class extends WebauthnCeremonyController {
  static targets = ["nickname", "submit"]

  connect() {
    if (!window.PublicKeyCredential) {
      this.showError("This browser doesn't support passkeys.")
      if (this.hasSubmitTarget) this.submitTarget.disabled = true
    }
  }

  register(event) {
    event.preventDefault()
    const nickname = this.hasNicknameTarget ? this.nicknameTarget.value : ""

    this.runCeremony({
      optionsBody: { nickname },
      authenticate: (options) => create({ publicKey: options }),
      callbackBody: (credential) => ({ credential, nickname }),
      errorMessage: "Passkey registration was cancelled or failed."
    })
  }
}
