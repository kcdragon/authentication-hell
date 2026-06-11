import { get } from "@github/webauthn-json"
import WebauthnCeremonyController from "lib/webauthn_ceremony_controller"

// Drives a passkey *assertion* ceremony: fetch request options from Rails, hand them
// to the authenticator, then POST the signed assertion back. Used for passwordless
// sign-in and for the passkey-as-second-factor challenge.
export default class extends WebauthnCeremonyController {
  connect() {
    if (!window.PublicKeyCredential) this.element.hidden = true
  }

  authenticate(event) {
    event.preventDefault()

    this.runCeremony({
      authenticate: (options) => get({ publicKey: options }),
      callbackBody: (credential) => ({ credential }),
      errorMessage: "Passkey sign-in was cancelled or failed."
    })
  }
}
