import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Navigates to a URL as soon as it connects
export default class extends Controller {
  static values = { url: String }

  connect() {
    Turbo.visit(this.urlValue)
  }
}
