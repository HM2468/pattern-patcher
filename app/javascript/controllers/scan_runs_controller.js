// app/javascript/controllers/scan_runs_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["bar", "phase", "done", "total", "failed", "error", "occCount"]

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
    // console.log("[ScanRuns] received", data)
    if (!data || data.id == null || !data.payload) return

    const id = String(data.id)

    // item root
    const item = this.element.querySelector(`[data-scan-run-id="${id}"]`)
    if (!item) return

    const payload = data.payload
    const phase = payload.phase ?? "unknown"
    const total = Number(payload.total ?? 0)
    const done = Number(payload.done ?? 0)
    const failed = Number(payload.failed ?? 0)
    const occCount = Number(payload.occ_count ?? 0)
    const error = payload.error

    // Update text fields
    item.querySelector('[data-scan-runs-target="phase"]').textContent = phase
    item.querySelector('[data-scan-runs-target="total"]').textContent = String(total)
    item.querySelector('[data-scan-runs-target="done"]').textContent = String(done)
    item.querySelector('[data-scan-runs-target="failed"]').textContent = String(failed)

    // Update occurrences count (live)
    const occEl = item.querySelector('[data-scan-runs-target="occCount"]')
    if (occEl) occEl.textContent = String(occCount)

    // Update bar width
    const bar = item.querySelector('[data-scan-runs-target="bar"]')
    if (bar) {
      const pct = total > 0 ? Math.max(0, Math.min(100, Math.round((done / total) * 100))) : 0
      bar.style.width = `${pct}%`
    }

    // Error
    const errEl = item.querySelector('[data-scan-runs-target="error"]')
    if (errEl) {
      if (error && String(error).trim().length > 0) {
        errEl.textContent = String(error)
        errEl.classList.remove("hidden")
      } else {
        errEl.textContent = ""
        errEl.classList.add("hidden")
      }
    }
  }
}