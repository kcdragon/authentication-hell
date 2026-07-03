import { Controller } from "@hotwired/stimulus"

// The vendored DragonRuby loader injects div#clicktoplaydiv asynchronously and
// can't be edited, so watch for it and rewrite its text to the poster copy.
export default class extends Controller {
  connect() {
    const existing = document.getElementById("clicktoplaydiv")
    if (existing) { this.rebrand(existing); return }

    this.observer = new MutationObserver((_records, observer) => {
      const div = document.getElementById("clicktoplaydiv")
      if (div) { this.rebrand(div); observer.disconnect() }
    })
    this.observer.observe(document.body, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  rebrand(div) {
    const ps = div.querySelectorAll("p")
    if (ps[0]) ps[0].textContent = "Authentication Hell"
    if (ps[1]) ps[1].textContent = "click or tap to begin onboarding"
  }
}
