import { get } from "@github/webauthn-json"
import WebauthnCeremonyController from "lib/webauthn_ceremony_controller"

// Step-up passkey re-auth for the in-game collision toast. Reuses the shared
// ceremony helpers (postJson + error display) and the optionsUrl/callbackUrl
// values from the base. Unlike sign-in there's no redirect on success — the
// server broadcasts the toast removal over Turbo Streams, so we only surface
// errors here.
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
