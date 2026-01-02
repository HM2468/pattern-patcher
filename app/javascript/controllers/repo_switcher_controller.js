// app/javascript/controllers/repo_switcher_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    showFrameId: String,
    filesFrameId: String,
    showUrlTemplate: String,
    filesUrlTemplate: String,
  }

  change(event) {
    const id = event.target.value
    if (!id) return

    const showFrame = document.getElementById(this.showFrameIdValue)
    const filesFrame = document.getElementById(this.filesFrameIdValue)

    if (showFrame) {
      showFrame.src = this.showUrlTemplateValue.replace("__ID__", id)
      showFrame.reload()
    }

    if (filesFrame) {
      filesFrame.src = this.filesUrlTemplateValue.replace("__ID__", id)
      filesFrame.reload()
    }
  }
}