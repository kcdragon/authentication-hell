import { Controller } from "@hotwired/stimulus"
import { get } from "@github/webauthn-json"

// Drives a passkey *assertion* ceremony: fetch request options from Rails, hand
// them to the authenticator, then POST the signed assertion back. Used for
// passwordless sign-in and for the passkey-as-second-factor challenge.
export default class extends Controller {
  static values = { optionsUrl: String, callbackUrl: String }
  static targets = ["error"]

  connect() {
    if (!window.PublicKeyCredential) this.element.hidden = true
  }

  async authenticate(event) {
    event.preventDefault()
    this.clearError()

    try {
      const options = await (await this.post(this.optionsUrlValue, {})).json()
      const credential = await get({ publicKey: options })
      const response = await this.post(this.callbackUrlValue, { credential })
      const data = await response.json()

      if (response.ok && data.redirect) {
        window.location.assign(data.redirect)
      } else {
        this.showError(data.error || "Could not sign in with that passkey.")
      }
    } catch (_error) {
      this.showError("Passkey sign-in was cancelled or failed.")
    }
  }

  post(url, body) {
    return fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify(body)
    })
  }

  showError(message) {
    if (this.hasErrorTarget) this.errorTarget.textContent = message
  }

  clearError() {
    if (this.hasErrorTarget) this.errorTarget.textContent = ""
  }
}
