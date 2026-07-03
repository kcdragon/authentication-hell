import { get } from "@github/webauthn-json"
import WebauthnCeremonyController from "lib/webauthn_ceremony_controller"

// No redirect on success — the server broadcasts the toast removal over Turbo
// Streams, so only errors surface here.
export default class extends WebauthnCeremonyController {
  async verify(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.clearError()
    button.disabled = true

    try {
      const options = await this.postJson(this.optionsUrlValue, {})
      const credential = await get({ publicKey: options })
      const data = await this.postJson(this.callbackUrlValue, { credential })
      if (!data.ok) this.showError(data.error || "That passkey didn't work. Please try again.")
    } catch (_error) {
      this.showError("Passkey verification was cancelled or failed.")
    } finally {
      button.disabled = false
    }
  }
}
