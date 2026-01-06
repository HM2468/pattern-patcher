// app/javascript/controllers/content_switcher_controller.js
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    showFrameId: String,
    showUrlTemplate: String,
    mainFrameId: String,
    mainUrlTemplate: String,
  }

  change(event) {
    const id = event.target.value
    if (!id) return

    // 1) Left show frame
    if (this.hasShowFrameIdValue && this.hasShowUrlTemplateValue) {
      const url = this._buildUrl(this.showUrlTemplateValue, id)
      Turbo.visit(url, { frame: this.showFrameIdValue })
    }

    // 2) Right main frame
    if (this.hasMainFrameIdValue && this.hasMainUrlTemplateValue) {
      const url = this._buildUrl(this.mainUrlTemplateValue, id)
      Turbo.visit(url, { frame: this.mainFrameIdValue })
    }
  }

  _buildUrl(template, id) {
    return template.includes("__ID__") ? template.replace("__ID__", id) : template
  }
}