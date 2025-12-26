// app/javascript/controllers/scan_runs_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["item", "bar", "phase", "done", "total", "failed", "error"]
  static values = { channel: String }

  connect() {
    this.subscription = consumer.subscriptions.create(
      { channel: "ScanRunsChannel" },
      { received: (data) => this.received(data) }
    )
  }

  disconnect() {
    if (this.subscription) consumer.subscriptions.remove(this.subscription)
  }

  received(data) {
    if (!data || !data.id || !data.payload) return

    const id = String(data.id)
    const item = this.itemTargets.find(el => String(el.dataset.scanRunId) === id)
    if (!item) return

    const payload = data.payload
    const phase = payload.phase ?? "unknown"
    const total = Number(payload.total ?? 0)
    const done = Number(payload.done ?? 0)
    const failed = Number(payload.failed ?? 0)
    const error = payload.error

    // Update text fields
    item.querySelector('[data-scan-runs-target="phase"]').textContent = phase
    item.querySelector('[data-scan-runs-target="total"]').textContent = String(total)
    item.querySelector('[data-scan-runs-target="done"]').textContent = String(done)
    item.querySelector('[data-scan-runs-target="failed"]').textContent = String(failed)

    // Update bar width (color comes from status; status not in payload here)
    const bar = item.querySelector('[data-scan-runs-target="bar"]')
    const pct = total > 0 ? Math.max(0, Math.min(100, Math.round((done / total) * 100))) : 0
    bar.style.width = `${pct}%`

    // Error
    const errEl = item.querySelector('[data-scan-runs-target="error"]')
    if (error && String(error).trim().length > 0) {
      errEl.textContent = String(error)
      errEl.classList.remove("hidden")
    } else {
      errEl.textContent = ""
      errEl.classList.add("hidden")
    }
  }
}