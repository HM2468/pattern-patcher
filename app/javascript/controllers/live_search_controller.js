// app/javascript/controllers/live_search_controller.js
import { Controller } from "@hotwired/stimulus"

// Usage:
// <input data-controller="live-search"
//        data-live-search-delay-value="1200"
//        data-live-search-url-template-value="/repository_files?repository_id=__REPO_ID__"
//        data-live-search-param-name-value="path_filter"
//        data-live-search-repo-id-value="3"
//        data-live-search-frame-id-value="repo_right"
//        data-live-search-min-length-value="0">
// - url_template: 后端接口（可包含 __REPO_ID__ 占位符）
// - param_name: 过滤参数名（默认 "q"）
// - frame_id: 需要刷新哪个 turbo-frame（默认 "repo_right"）
// - delay: 停止输入多久触发（ms）
// - min_length: 最小触发长度（默认 0；比如 2 表示至少输入2个字符才触发）
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 1200 },
    urlTemplate: String,
    paramName: { type: String, default: "q" },
    repoId: String,
    frameId: { type: String, default: "repo_right" },
    minLength: { type: Number, default: 0 },
  }

  connect() {
    this._timer = null
    this._last = null
    this._onInput = this._onInput.bind(this)
    this.element.addEventListener("input", this._onInput)
  }

  disconnect() {
    this.element.removeEventListener("input", this._onInput)
    if (this._timer) clearTimeout(this._timer)
  }

  _onInput() {
    if (this._timer) clearTimeout(this._timer)
    this._timer = setTimeout(() => this.run(), this.delayValue)
  }

  run() {
    const raw = (this.element.value || "")
    const value = raw.trim()

    // 去抖后，如果内容没变化就不刷新
    if (value === this._last) return
    this._last = value

    if (value.length < this.minLengthValue) return

    const frameId = this.frameIdValue || "repo_right"
    const frame = document.getElementById(frameId)
    if (!frame) return

    let url = this.urlTemplateValue || ""
    if (!url) return

    // 支持 __REPO_ID__ 替换
    if (this.repoIdValue) {
      url = url.replaceAll("__REPO_ID__", encodeURIComponent(this.repoIdValue))
    }

    // 拼 query
    const u = new URL(url, window.location.origin)

    // 清理分页，避免搜索仍停留在旧页
    u.searchParams.delete("page")

    // 保证互斥：如果当前是 text_filter，就清掉 path_filter；反之亦然
    const pn = (this.paramNameValue || "q")
    if (pn === "text_filter") u.searchParams.delete("path_filter")
    if (pn === "path_filter") u.searchParams.delete("text_filter")

    if (value.length > 0) {
      u.searchParams.set(pn, value)
    } else {
      // 允许清空过滤时回到无过滤状态：移除该参数
      u.searchParams.delete(pn)
    }

    // 通过 turbo-frame 刷新右侧区域
    frame.src = u.toString()
    frame.reload()
  }
}