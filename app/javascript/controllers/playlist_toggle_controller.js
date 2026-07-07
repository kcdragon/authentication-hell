import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "game:playlist-collapsed"

export default class extends Controller {
  static targets = ["panel", "game", "rail", "collapse"]
  static values = { collapsed: Boolean }

  connect() {
    this.collapsedValue = localStorage.getItem(STORAGE_KEY) === "true"
  }

  collapse() {
    this.collapsedValue = true
  }

  expand() {
    this.collapsedValue = false
  }

  collapsedValueChanged() {
    localStorage.setItem(STORAGE_KEY, String(this.collapsedValue))
    this.render()
  }

  panelTargetConnected() {
    this.render()
  }

  render() {
    const collapsed = this.collapsedValue

    this.panelTarget.classList.toggle("lg:hidden", collapsed)
    this.gameTarget.classList.toggle("lg:max-w-none", collapsed)
    this.railTarget.classList.toggle("lg:flex", collapsed)
    this.railTarget.setAttribute("aria-expanded", String(collapsed))
    this.collapseTarget.setAttribute("aria-expanded", String(!collapsed))
  }
}
