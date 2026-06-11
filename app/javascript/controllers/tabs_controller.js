import { Controller } from "@hotwired/stimulus"

// A simple tabbed interface. Each tab button and each panel carries a data-tabs-name;
// selecting a tab shows the matching panel and hides the rest. The initially active
// tab comes from the active value (defaults to the first tab). Active/inactive styling
// is supplied by the view via data-tabs-active-class / data-tabs-inactive-class, so
// the controller stays presentation-agnostic.
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
