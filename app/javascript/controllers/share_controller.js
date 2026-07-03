import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, text: String, awardPath: String }
  static targets = ["native", "copyLabel"]

  connect() {
    if (this.hasNativeTarget && !navigator.share) this.nativeTarget.hidden = true
  }

  async native() {
    try {
      await navigator.share({ title: "Authentication Hell", text: this.textValue, url: this.urlValue })
    } catch (e) {
      if (e.name === "AbortError") return
    }
    this.award()
  }

  x() {
    this.open(`https://twitter.com/intent/tweet?text=${this.enc(this.textValue)}&url=${this.enc(this.urlValue)}`)
  }

  linkedin() {
    this.open(`https://www.linkedin.com/sharing/share-offsite/?url=${this.enc(this.urlValue)}`)
  }

  bluesky() {
    this.open(`https://bsky.app/intent/compose?text=${this.enc(`${this.textValue} ${this.urlValue}`)}`)
  }

  mastodon() {
    const instance = window.prompt("Your Mastodon instance (e.g. ruby.social)")
    if (!instance) return
    const host = instance.replace(/^https?:\/\//, "").replace(/\/+$/, "")
    this.open(`https://${host}/share?text=${this.enc(`${this.textValue} ${this.urlValue}`)}`)
  }

  async copy() {
    await navigator.clipboard.writeText(this.urlValue)
    if (this.hasCopyLabelTarget) {
      const original = this.copyLabelTarget.textContent
      this.copyLabelTarget.textContent = "Copied!"
      setTimeout(() => (this.copyLabelTarget.textContent = original), 1500)
    }
    this.award()
  }

  open(url) {
    window.open(url, "_blank", "noopener,noreferrer")
    this.award()
  }

  enc(value) {
    return encodeURIComponent(value)
  }

  award() {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.awardPathValue, {
      method: "POST",
      headers: { "X-CSRF-Token": token, "Accept": "text/vnd.turbo-stream.html" }
    })
  }
}
