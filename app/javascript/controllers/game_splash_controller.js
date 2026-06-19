import { Controller } from "@hotwired/stimulus"

// The DragonRuby HTML5 loader injects its splash (div#clicktoplaydiv: a logo + a
// title <p> + a "Click or tap…" <p>) into the document body once assets finish
// downloading. We can't edit that vendored JS, so once the splash appears we rewrite
// its two text lines to the in-game poster's copy (its look is handled by
// game_splash.css). Attached to the iframe body; it watches for the splash node,
// which the loader adds asynchronously after this controller has connected.
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
