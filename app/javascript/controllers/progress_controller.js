import { Controller } from "@hotwired/stimulus"
import { subscribeToDownload, unsubscribeFromDownload } from "../channels/download_channel"

export default class extends Controller {
  static values = { downloadId: Number }
  static targets = ["bar", "text"]

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
      this.textTarget.textContent = `${data.progress}% (${data.current_chapter}/${data.total_chapters})`
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
    }

    const statusEl = this.element.querySelector(".text-xs.text-gray-500")
    if (statusEl && data.title) {
      const titleEl = this.element.querySelector(".font-medium")
      if (titleEl) titleEl.textContent = data.title
    }
  }
}
