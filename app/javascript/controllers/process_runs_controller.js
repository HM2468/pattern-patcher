// app/javascript/controllers/process_runs_controller.js
import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

// 监听 ActionCable 广播到 process_runs 的消息：
// {id, kind, ts, payload: {status, total, succeeded, failed, processed, percent, batches_total, batches_done, occ_revc}}
export default class extends Controller {
  static values = {
    processRunsChannel: String,
  }

  connect() {
    const channelName = this.processRunsChannelValue || "ProcessRunsChannel"

    this.subscription = consumer.subscriptions.create(
      { channel: channelName },
      {
        received: (data) => this.received(data),
      }
    )
  }

  disconnect() {
    if (this.subscription) {
      consumer.subscriptions.remove(this.subscription)
      this.subscription = null
    }
  }

  received(data) {
    if (!data || typeof data !== "object") return
    const runId = data.id
    const payload = data.payload || {}
    if (!runId) return

    const card = document.getElementById(`process_run_${runId}`)
    if (!card) return

    // update progress percent + bar
    if (payload.percent !== undefined && payload.percent !== null) {
      const pct = Number(payload.percent)
      if (!Number.isNaN(pct)) {
        this.setText(card, '[data-process-runs-target="percent"]', `${pct.toFixed(2)}%`)
        this.setStyleWidth(card, '[data-process-runs-target="bar"]', `${Math.max(0, Math.min(100, pct))}%`)
      }
    }

    // update counters (real-time)
    this.setNumber(card, '[data-process-runs-target="succeeded"]', payload.succeeded)
    this.setNumber(card, '[data-process-runs-target="failed"]', payload.failed)
    this.setNumber(card, '[data-process-runs-target="processed"]', payload.processed)
    this.setNumber(card, '[data-process-runs-target="occRevc"]', payload.occ_revc)

    // batches
    this.setNumber(card, '[data-process-runs-target="batchesTotal"]', payload.batches_total)
    this.setNumber(card, '[data-process-runs-target="batchesDone"]', payload.batches_done)

    // status rule: only live-update when current status is running
    const currentStatus = (card.dataset.processRunStatus || "").toString()
    if (currentStatus === "running" && payload.status) {
      this.setText(card, '[data-process-runs-target="status"]', payload.status)
      // 同步 dataset，避免后续仍被当作 running（比如已变成 succeeded/failed）
      card.dataset.processRunStatus = payload.status
    }
  }

  // helpers
  setText(root, selector, value) {
    if (value === undefined || value === null) return
    const el = root.querySelector(selector)
    if (!el) return
    el.textContent = String(value)
  }

  setNumber(root, selector, value) {
    if (value === undefined || value === null) return
    const n = Number(value)
    if (Number.isNaN(n)) return
    const el = root.querySelector(selector)
    if (!el) return
    el.textContent = String(n)
  }

  setStyleWidth(root, selector, width) {
    const el = root.querySelector(selector)
    if (!el) return
    el.style.width = width
  }
}