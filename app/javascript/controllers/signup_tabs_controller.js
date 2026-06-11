import { Controller } from "@hotwired/stimulus"

// A segmented toggle between the password and passkey signup forms. Each tab button
// and each panel carries a data-signup-tabs-name; selecting a tab shows the matching
// panel. The initially active tab comes from the active value (set server-side so a
// failed submission reopens the form the user was using).
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }

  connect() {
    this.show(this.activeValue || this.tabTargets[0]?.dataset.signupTabsName)
  }

  select(event) {
    this.show(event.currentTarget.dataset.signupTabsName)
  }

  show(name) {
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.signupTabsName !== name
    })
    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.signupTabsName === name
      tab.classList.toggle("bg-white", active)
      tab.classList.toggle("shadow-sm", active)
      tab.classList.toggle("text-gray-900", active)
      tab.classList.toggle("text-gray-500", !active)
    })
  }
}
