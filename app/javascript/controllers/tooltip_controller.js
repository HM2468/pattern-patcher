// app/javascript/controllers/tooltip_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String,
    placement: { type: String, default: "top" }, // top | bottom
  }

  connect() {
    // Ensure the element can be a positioning anchor
    this._tooltipEl = null
    this._visible = false

    this._onEnter = () => this.show()
    this._onLeave = () => this.hide()
    this._onFocus = () => this.show()
    this._onBlur = () => this.hide()
    this._onScroll = () => this.position()
    this._onResize = () => this.position()

    this.element.addEventListener("mouseenter", this._onEnter)
    this.element.addEventListener("mouseleave", this._onLeave)
    this.element.addEventListener("focus", this._onFocus)
    this.element.addEventListener("blur", this._onBlur)

    // Optional: keep native title for accessibility, but avoid double-tooltips
    this._nativeTitle = this.element.getAttribute("title")
    if (!this._nativeTitle && this.hasTextValue) {
      this.element.setAttribute("title", this.textValue)
      this._nativeTitle = this.textValue
    }
    // Prevent native tooltip from showing (it has delay + can conflict)
    if (this._nativeTitle) {
      this.element.setAttribute("data-native-title", this._nativeTitle)
      this.element.removeAttribute("title")
    }
  }

  disconnect() {
    this.hide(true)

    this.element.removeEventListener("mouseenter", this._onEnter)
    this.element.removeEventListener("mouseleave", this._onLeave)
    this.element.removeEventListener("focus", this._onFocus)
    this.element.removeEventListener("blur", this._onBlur)

    // restore title
    const t = this.element.getAttribute("data-native-title")
    if (t) this.element.setAttribute("title", t)
  }

  show() {
    const text = this.textValue || this.element.dataset.tooltip
    if (!text) return

    if (!this._tooltipEl) {
      this._tooltipEl = document.createElement("div")
      this._tooltipEl.className = "app-tooltip"
      this._tooltipEl.setAttribute("role", "tooltip")
      document.body.appendChild(this._tooltipEl)
    }

    this._tooltipEl.textContent = text
    this._tooltipEl.style.opacity = "0"
    this._tooltipEl.style.visibility = "hidden"

    this._visible = true

    // position first, then show (next frame) for stable measurement
    this.position()

    requestAnimationFrame(() => {
      if (!this._tooltipEl || !this._visible) return
      this._tooltipEl.style.opacity = "1"
      this._tooltipEl.style.visibility = "visible"
    })

    window.addEventListener("scroll", this._onScroll, true) // capture, so nested scroll works
    window.addEventListener("resize", this._onResize)
  }

  hide(immediate = false) {
    this._visible = false
    window.removeEventListener("scroll", this._onScroll, true)
    window.removeEventListener("resize", this._onResize)

    if (!this._tooltipEl) return

    if (immediate) {
      this._tooltipEl.remove()
      this._tooltipEl = null
      return
    }

    this._tooltipEl.style.opacity = "0"
    this._tooltipEl.style.visibility = "hidden"

    // remove after transition
    setTimeout(() => {
      if (this._tooltipEl && !this._visible) {
        this._tooltipEl.remove()
        this._tooltipEl = null
      }
    }, 120)
  }

  position() {
    if (!this._tooltipEl) return

    const rect = this.element.getBoundingClientRect()
    const tip = this._tooltipEl

    // Make tooltip measurable
    tip.style.left = "0px"
    tip.style.top = "0px"
    tip.style.transform = "translate(-9999px, -9999px)"

    // force layout
    const tipRect = tip.getBoundingClientRect()

    const gap = 10
    const placement = this.placementValue || "top"

    // Center horizontally
    let left = rect.left + (rect.width / 2) - (tipRect.width / 2)

    // Clamp within viewport
    const minLeft = 8
    const maxLeft = window.innerWidth - tipRect.width - 8
    left = Math.max(minLeft, Math.min(maxLeft, left))

    let top
    if (placement === "bottom") {
      top = rect.bottom + gap
      // If bottom overflows, flip to top
      if (top + tipRect.height > window.innerHeight - 8) {
        top = rect.top - gap - tipRect.height
      }
    } else {
      top = rect.top - gap - tipRect.height
      // If top overflows, flip to bottom
      if (top < 8) {
        top = rect.bottom + gap
      }
    }

    tip.style.transform = "translate(0, 0)"
    tip.style.left = `${Math.round(left)}px`
    tip.style.top = `${Math.round(top)}px`
  }
}