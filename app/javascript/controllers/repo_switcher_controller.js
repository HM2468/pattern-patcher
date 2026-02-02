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

    // left side show frame
    Turbo.visit(this.showUrlTemplateValue.replace("__ID__", id), { frame: "repo_show" })

    // right side files frame
    Turbo.visit(this.filesUrlTemplateValue.replace("__ID__", id), { frame: "repo_right" })
  }
}