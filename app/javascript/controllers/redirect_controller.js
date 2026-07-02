import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Navigates to a URL as soon as it connects. Broadcast onto the game page when the
// player beats the final level to send them to their certificate.
export default class extends Controller {
  static values = { url: String }

  connect() {
    Turbo.visit(this.urlValue)
  }
}
