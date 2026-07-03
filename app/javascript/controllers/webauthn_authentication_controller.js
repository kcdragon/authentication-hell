import { get } from "@github/webauthn-json"
import WebauthnCeremonyController from "lib/webauthn_ceremony_controller"

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
