// app/javascript/controllers/repo_switcher_controller.js
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    showUrlTemplate: String,
    filesUrlTemplate: String,
  }

  change(event) {
    const id = event.target.value
    if (!id) return

    // 左侧 show frame
    Turbo.visit(this.showUrlTemplateValue.replace("__ID__", id), { frame: "repo_show" })

    // 右侧主区域：默认切到 files（你也可以切到 scan_runs 等）
    Turbo.visit(this.filesUrlTemplateValue.replace("__ID__", id), { frame: "repo_right" })
  }
}