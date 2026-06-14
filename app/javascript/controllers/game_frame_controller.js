import { Controller } from "@hotwired/stimulus"

// The game's canvas lives in a same-origin <iframe> (so the DragonRuby engine can
// fill the frame at a true 16:9 with no letterbox). Answering a challenge toast,
// which lives on this parent document, moves keyboard focus out of the frame — so
// the game would stay deaf to keys until clicked again. When a resolved toast is
// removed from the toast container, hand focus back to the frame so the player can
// keep moving without re-clicking. The element this controller is attached to is
// the <iframe>; it watches the toast container named by the `toasts` value.
export default class extends Controller {
  static values = { toasts: String }

  connect() {
    const container = document.getElementById(this.toastsValue)
    if (!container) return

    this.observer = new MutationObserver((records) => {
      if (records.some((r) => r.removedNodes.length > 0)) this.refocus()
    })
    this.observer.observe(container, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  refocus() {
    // Same-origin frame, so reaching into its document is allowed; guard anyway.
    try {
      this.element.contentWindow?.focus()
      this.element.contentWindow?.document.getElementById("canvas")?.focus()
    } catch { /* cross-origin would throw; not our case */ }
  }
}
