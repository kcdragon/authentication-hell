import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "toggle"]
  static values = {
    expandedGlyph: { type: String, default: "−" },
    collapsedGlyph: { type: String, default: "+" }
  }

  toggle() {
    const collapsed = !this.bodyTarget.hidden
    this.bodyTarget.hidden = collapsed
    this.toggleTarget.textContent = collapsed ? this.collapsedGlyphValue : this.expandedGlyphValue
    this.toggleTarget.setAttribute("aria-label", collapsed ? "Expand" : "Collapse")
    this.toggleTarget.setAttribute("aria-expanded", String(!collapsed))
  }
}
