// app/javascript/controllers/sidebar_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["left", "line", "collapseIcon", "expandIcon"]

  connect() {
    const collapsed = window.localStorage.getItem(this.storageKey()) === "1"
    this.applyCollapsed(collapsed)
  }

  toggle() {
    const collapsed = !this.isCollapsed()
    this.applyCollapsed(collapsed)
    window.localStorage.setItem(this.storageKey(), collapsed ? "1" : "0")
  }

  applyCollapsed(collapsed) {
    // Hide/show the left sidebar
    this.leftTarget.classList.toggle("hidden", collapsed)

    // Hide/show the divider line for a cleaner "full screen" feel
    this.lineTarget.classList.toggle("hidden", collapsed)

    // Toggle icons:
    // expanded  => show collapse icon (<<), hide expand icon (>>)
    // collapsed => hide collapse icon (<<), show expand icon (>>)
    this.collapseIconTarget.classList.toggle("hidden", collapsed)
    this.expandIconTarget.classList.toggle("hidden", !collapsed)
  }

  isCollapsed() {
    return this.leftTarget.classList.contains("hidden")
  }

  storageKey() {
    return "processor_workspace.sidebar_collapsed"
  }
}