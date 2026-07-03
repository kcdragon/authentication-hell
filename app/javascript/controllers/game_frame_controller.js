import { Controller } from "@hotwired/stimulus"

// Answering a challenge toast moves keyboard focus out of the game <iframe>,
// leaving the game deaf to keys until clicked again — so when a toast is removed,
// hand focus back to the frame.
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
    try {
      this.element.contentWindow?.focus()
      this.element.contentWindow?.document.getElementById("canvas")?.focus()
    } catch {}
  }
}
