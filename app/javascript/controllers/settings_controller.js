import { Controller } from "@hotwired/stimulus"
import { subscribeToSettings, unsubscribeFromSettings } from "channels/settings_channel"

export default class extends Controller {
  static targets = ["errors"]

  connect() {
    subscribeToSettings({
      onValidationError: (data) => this.showErrors(data.errors),
      onSaved: () => this.clearErrors()
    })
  }

  disconnect() {
    unsubscribeFromSettings()
  }

  showErrors(errors) {
    if (!this.hasErrorsTarget) return

    this.errorsTarget.innerHTML = errors.map(e =>
      `<p class="text-red-400 text-sm">${e}</p>`
    ).join("")
    this.errorsTarget.classList.remove("hidden")
  }

  clearErrors() {
    if (!this.hasErrorsTarget) return

    this.errorsTarget.innerHTML = ""
    this.errorsTarget.classList.add("hidden")
  }
}
