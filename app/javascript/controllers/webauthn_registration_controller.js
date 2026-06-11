import { Controller } from "@hotwired/stimulus"
import { create } from "@github/webauthn-json"

// Drives a passkey *registration* ceremony: fetch creation options from Rails,
// hand them to the authenticator via @github/webauthn-json, then POST the new
// credential back. Used on the settings "Add a passkey" form and passwordless signup.
export default class extends Controller {
  static values = { optionsUrl: String, callbackUrl: String }
  static targets = ["nickname", "error", "submit"]

  connect() {
    if (!window.PublicKeyCredential) {
      this.showError("This browser doesn't support passkeys.")
      if (this.hasSubmitTarget) this.submitTarget.disabled = true
    }
  }

  async register(event) {
    event.preventDefault()
    this.clearError()
    const nickname = this.hasNicknameTarget ? this.nicknameTarget.value : ""

    try {
      const options = await (await this.post(this.optionsUrlValue, { nickname })).json()
      const credential = await create({ publicKey: options })
      const response = await this.post(this.callbackUrlValue, { credential, nickname })
      const data = await response.json()

      if (response.ok && data.redirect) {
        window.location.assign(data.redirect)
      } else {
        this.showError(data.error || "Could not register that passkey.")
      }
    } catch (_error) {
      this.showError("Passkey registration was cancelled or failed.")
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
