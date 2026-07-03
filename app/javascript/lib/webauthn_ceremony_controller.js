import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { optionsUrl: String, callbackUrl: String }
  static targets = ["error"]

  async runCeremony({ optionsBody = {}, authenticate, callbackBody, errorMessage }) {
    this.clearError()

    try {
      const options = await this.postJson(this.optionsUrlValue, optionsBody)
      const credential = await authenticate(options)
      const data = await this.postJson(this.callbackUrlValue, callbackBody(credential))

      if (data.redirect) {
        window.location.assign(data.redirect)
      } else {
        this.showError(data.error || errorMessage)
      }
    } catch (_error) {
      this.showError(errorMessage)
    }
  }

  async postJson(url, body) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify(body)
    })
    return response.json()
  }

  showError(message) {
    if (this.hasErrorTarget) this.errorTarget.textContent = message
  }

  clearError() {
    if (this.hasErrorTarget) this.errorTarget.textContent = ""
  }
}
