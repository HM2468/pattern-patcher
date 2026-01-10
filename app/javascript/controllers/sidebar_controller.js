import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["left", "line", "icon"]

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

    // Optional: hide the divider line when collapsed (cleaner "full screen" feel)
    this.lineTarget.classList.toggle("hidden", collapsed)

    // Update arrow: collapsed => show expand ▶, expanded => show collapse ◀
    this.iconTarget.textContent = collapsed ? "▶" : "◀"
  }

  isCollapsed() {
    return this.leftTarget.classList.contains("hidden")
  }

  storageKey() {
    return "processor_workspace.sidebar_collapsed"
  }
}