import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "results", "urlInput", "source", "sort"]

  connect() {
    this.offset = 0
    this.total = 0
    this.loading = false
    this.query = ""
    this.debounceTimer = null
  }

  search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.performSearch(), 300)
  }

  performSearch() {
    const query = this.inputTarget.value.trim()
    if (query.length < 2) {
      this.hideDropdown()
      return
    }

    this.query = query
    this.offset = 0
    this.resultsTarget.innerHTML = ""
    this.fetchResults()
  }

  async fetchResults() {
    if (this.loading) return
    if (this.offset > 0 && this.offset >= this.total) return
    this.loading = true

    try {
      const source = this.hasSourceTarget ? this.sourceTarget.value : "mangadex"
      const sort = this.hasSortTarget ? this.sortTarget.value : "relevance"
      const response = await fetch(`/search?q=${encodeURIComponent(this.query)}&offset=${this.offset}&source=${source}&sort=${sort}`)
      const data = await response.json()

      this.total = data.total
      this.appendResults(data.results)
      this.offset += data.results.length
      this.showDropdown()
    } finally {
      this.loading = false
    }
  }

  appendResults(results) {
    results.forEach(manga => {
      const item = document.createElement("div")
      item.className = "flex items-center gap-3 px-3 py-2 hover:bg-gray-700 cursor-pointer"
      item.dataset.url = manga.url
      item.dataset.title = manga.title
      item.dataset.action = "click->manga-search#select"

      if (manga.thumbnail) {
        const img = document.createElement("img")
        img.src = manga.thumbnail
        img.className = "w-8 h-11 object-cover rounded flex-shrink-0"
        img.loading = "lazy"
        item.appendChild(img)
      }

      const text = document.createElement("span")
      text.className = "text-sm text-white truncate"
      text.textContent = manga.title
      item.appendChild(text)

      this.resultsTarget.appendChild(item)
    })
  }

  select(event) {
    const item = event.currentTarget
    this.inputTarget.value = item.dataset.title
    this.urlInputTarget.value = item.dataset.url
    this.hideDropdown()
  }

  scroll() {
    const el = this.resultsTarget
    if (el.scrollTop + el.clientHeight >= el.scrollHeight - 10) {
      this.fetchResults()
    }
  }

  hideOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDropdown()
    }
  }

  showDropdown() {
    this.dropdownTarget.classList.remove("hidden")
  }

  hideDropdown() {
    this.dropdownTarget.classList.add("hidden")
  }
}
