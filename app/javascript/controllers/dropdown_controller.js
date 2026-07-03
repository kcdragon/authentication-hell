import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("mousedown", this.closeOnOutsideClick)
    document.addEventListener("keydown", this.closeOnEscape)
  }

  disconnect() {
    document.removeEventListener("mousedown", this.closeOnOutsideClick)
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  toggle() {
    this.menuTarget.hidden = !this.menuTarget.hidden
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.menuTarget.hidden = true
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.menuTarget.hidden = true
  }
}
