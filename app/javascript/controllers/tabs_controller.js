import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }
  static classes = ["active", "inactive"]

  connect() {
    this.show(this.activeValue || this.tabTargets[0]?.dataset.tabsName)
  }

  select(event) {
    this.show(event.currentTarget.dataset.tabsName)
  }

  show(name) {
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tabsName !== name
    })
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.tabsName === name
      tab.classList.add(...(active ? this.activeClasses : this.inactiveClasses))
      tab.classList.remove(...(active ? this.inactiveClasses : this.activeClasses))
    })
  }
}
