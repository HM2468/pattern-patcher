// app/javascript/controllers/live_search_controller.js
import { Controller } from "@hotwired/stimulus"

// Usage:
// <input data-controller="live-search"
//        data-live-search-delay-value="1200"
//        data-live-search-url-template-value="/repository_files?repository_id=__REPO_ID__"
//        data-live-search-param-name-value="path_filter"
//        data-live-search-repo-id-value="3"
//        data-live-search-frame-id-value="repo_right"
//        data-live-search-min-length-value="0">
// - url_template: backend endpoint (may include the __REPO_ID__ placeholder)
// - param_name: query parameter name (default: "q")
// - frame_id: which turbo-frame to refresh (default: "repo_right")
// - delay: debounce delay after typing stops (ms)
// - min_length: minimum input length to trigger (default: 0; e.g., 2 means trigger only when >= 2 chars)
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 1200 },
    urlTemplate: String,
    paramName: { type: String, default: "q" },
    repoId: String,
    frameId: { type: String, default: "repo_right" },
    minLength: { type: Number, default: 0 },
  }

  connect() {
    this._timer = null
    this._last = null
    this._onInput = this._onInput.bind(this)
    this.element.addEventListener("input", this._onInput)
  }

  disconnect() {
    this.element.removeEventListener("input", this._onInput)
    if (this._timer) clearTimeout(this._timer)
  }

  _onInput() {
    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(() => this.run(), this.delayValue)
  }

  run() {
    const raw = (this.element.value || "")
    const value = raw.trim()

    // After debounce, do not refresh if the value hasn't changed
    if (value === this._last) return
    this._last = value

    if (value.length < this.minLengthValue) return

    const frameId = this.frameIdValue || "repo_right"
    const frame = document.getElementById(frameId)
    if (!frame) return

    let url = this.urlTemplateValue || ""
    if (!url) return

    // Support __REPO_ID__ placeholder replacement
    if (this.repoIdValue) {
      url = url.replaceAll("__REPO_ID__", encodeURIComponent(this.repoIdValue))
    }

    // Build query params
    const u = new URL(url, window.location.origin)

    // Reset pagination so searches don't stay on an old page
    u.searchParams.delete("page")

    // Enforce mutual exclusivity: if using text_filter, clear path_filter; and vice versa
    const pn = (this.paramNameValue || "q")
    if (pn === "text_filter") u.searchParams.delete("path_filter")
    if (pn === "path_filter") u.searchParams.delete("text_filter")

    if (value.length > 0) {
      u.searchParams.set(pn, value)
    } else {
      // Allow clearing the filter to return to the unfiltered state: remove this param
      u.searchParams.delete(pn)
    }

    // Refresh the target area via turbo-frame
    frame.src = u.toString()
    frame.reload()
  }
}