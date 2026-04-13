import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.submitting = false
    this.element.addEventListener("turbo:submit-end", () => {
      this.submitting = false
    })
  }

  submit(event) {
    if (this.submitting) {
      event.preventDefault()
      return
    }
    this.submitting = true
  }
}
