import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String,
    copiedTip: { type: String, default: "copied" },
    defaultTip: { type: String, default: "copy" },
    resetAfter: { type: Number, default: 1200 },
  }

  async copy(event) {
    event.preventDefault()

    const text = this.textValue || ""
    if (!text) return

    try {
      await this.writeToClipboard(text)

      // Show "copied" immediately
      this.setTooltip(this.copiedTipValue, { reopen: true })

      // Restore tooltip text after delay (no forced reopen)
      window.setTimeout(() => {
        this.setTooltip(this.defaultTipValue, { reopen: false })
      }, this.resetAfterValue)
    } catch (e) {
      // optional: this.setTooltip("failed", { reopen: true })
      // console.error(e)
    }
  }

  /**
   * Update tooltip text and optionally force it to re-open.
   *
   * @param {String} tip
   * @param {Object} options
   * @param {Boolean} options.reopen
   */
  setTooltip(tip, { reopen } = {}) {
    // tooltip_data uses data-tooltip-text-value
    this.element.dataset.tooltipTextValue = tip
    this.element.setAttribute("title", tip) // fallback for native tooltip

    // Key fix:
    // Tooltip text usually updates only on mouseenter.
    // Force a synthetic mouseenter so tooltip refreshes immediately.
    if (reopen) {
      this.element.dispatchEvent(
        new Event("mouseenter", { bubbles: true })
      )
    }
  }

  async writeToClipboard(text) {
    if (navigator.clipboard?.writeText) {
      return navigator.clipboard.writeText(text)
    }

    // Fallback for older browsers
    const ta = document.createElement("textarea")
    ta.value = text
    ta.setAttribute("readonly", "")
    ta.style.position = "absolute"
    ta.style.left = "-9999px"
    document.body.appendChild(ta)
    ta.select()
    document.execCommand("copy")
    document.body.removeChild(ta)
  }
}