import { Controller } from "@hotwired/stimulus"
import { subscribeToDownload, unsubscribeFromDownload } from "channels/download_channel"

export default class extends Controller {
  static values = { downloadId: Number }
  static targets = ["bar", "text", "status", "title"]

  connect() {
    subscribeToDownload(this.downloadIdValue, {
      onProgress: (data) => this.updateProgress(data),
      onLog: (data) => this.appendLog(data),
      onStatus: (data) => this.handleStatus(data)
    })
  }

  disconnect() {
    unsubscribeFromDownload(this.downloadIdValue)
  }

  updateProgress(data) {
    if (this.hasBarTarget) {
      this.barTarget.style.width = `${data.progress}%`
    }
    if (this.hasTextTarget) {
      this.textTarget.textContent = `${data.progress}% (${data.downloaded_images}/${data.total_images} images)`
    }
  }

  appendLog(data) {
    const container = this.element.querySelector("[data-log-panel-target='container']")
    if (!container) return

    const div = document.createElement("div")
    div.className = data.level === "error" ? "text-red-400" : data.level === "warn" ? "text-yellow-400" : "text-gray-400"
    div.textContent = data.message
    container.appendChild(div)
    container.scrollTop = container.scrollHeight
  }

  handleStatus(data) {
    if (data.status === "completed" || data.status === "failed") {
      window.location.reload()
      return
    }

    if (this.hasTitleTarget && data.title) {
      this.titleTarget.textContent = data.title
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.humanize(data.status)
    }
  }

  humanize(status) {
    return status.charAt(0).toUpperCase() + status.slice(1).replace(/_/g, " ")
  }
}
