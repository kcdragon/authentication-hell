import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]
  static values = { codes: Array }

  async copy() {
    if (!navigator.clipboard) return this.flash("Copy not supported")
    await navigator.clipboard.writeText(this.text())
    this.flash("Copied!")
  }

  download() {
    const url = URL.createObjectURL(new Blob([this.text()], { type: "text/plain" }))
    const link = document.createElement("a")
    link.href = url
    link.download = "authentication-hell-recovery-codes.txt"
    link.click()
    URL.revokeObjectURL(url)
    this.flash("Downloaded")
  }

  disconnect() {
    clearTimeout(this.statusTimeout)
  }

  text() {
    return this.codesValue.join("\n") + "\n"
  }

  flash(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    clearTimeout(this.statusTimeout)
    this.statusTimeout = setTimeout(() => { this.statusTarget.textContent = "" }, 2000)
  }
}
