// app/javascript/controllers/repo_files_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "checkAll",
    "hint",
    "fileCheck",
    "bulkScanBtn",
    "bulkDeleteBtn",
    "scanIdsBox",
    "deleteIdsBox",
    "scanTrigger",
    "deleteTrigger",
  ];

  static values = {
    repoId: Number,
    scanHintMessage: String,
  };

  connect() {
    // 初始状态：按钮禁用 + 同步全选状态
    this.updateHintAndButtons();
    this.syncCheckAllState();

    // Select All：用事件监听绑定在当前节点上（Turbo replace 后会自动重新 connect）
    if (this.hasCheckAllTarget) {
      this._onCheckAllChange = this.onCheckAllChange.bind(this);
      this.checkAllTarget.addEventListener("change", this._onCheckAllChange);
    }
  }

  disconnect() {
    if (this.hasCheckAllTarget && this._onCheckAllChange) {
      this.checkAllTarget.removeEventListener("change", this._onCheckAllChange);
    }
  }

  // tbody change：任意 file checkbox 改变都走这里
  onTbodyChange(e) {
    const t = e.target;
    if (!t) return;

    // file checkbox
    if (t.matches && t.matches('input[data-file-check="1"]')) {
      this.syncCheckAllState();
      this.updateHintAndButtons();
    }
  }

  onCheckAllChange() {
    const checked = !!this.checkAllTarget.checked;

    // 永远选中当前页的所有 file checkbox（只查 this.element 内部）
    this.fileChecks().forEach((c) => {
      c.checked = checked;
    });

    this.updateHintAndButtons();
  }

  onBulkDeleteClick() {
    const ids = this.selectedIds();
    if (ids.length === 0) return; // disabled anyway

    this.fillHiddenIds(this.deleteIdsBoxTarget, ids);

    if (!this.hasDeleteTriggerTarget) {
      console.warn("[repo_files] bulk_delete_trigger not found");
      return;
    }
    this.deleteTriggerTarget.click();
  }

  onBulkScanClick() {
    const ids = this.selectedIds();
    if (ids.length === 0) return; // disabled anyway

    this.fillHiddenIds(this.scanIdsBoxTarget, ids);

    if (!this.hasScanTriggerTarget) {
      console.warn("[repo_files] bulk_scan_trigger not found");
      return;
    }

    // 只保留一个 scan_hint_message（按你的要求移除 scan_all_hint）
    const msg = this.scanHintMessageValue || "";
    if (msg.length > 0) {
      this.scanTriggerTarget.dataset.confirmMessageHtml = msg;
    }

    this.scanTriggerTarget.click();
  }

  // -------- helpers --------

  fileChecks() {
    // 只在当前 panel 内查找，避免拿到别的页面/frame 的 checkbox
    return this.hasFileCheckTarget ? this.fileCheckTargets : [];
  }

  selectedIds() {
    return this.fileChecks()
      .filter((x) => x.checked)
      .map((x) => x.value);
  }

  updateHintAndButtons() {
    const count = this.selectedIds().length;

    if (this.hasHintTarget) {
      this.hintTarget.textContent = count > 0 ? `Selected: ${count}` : "200/page";
    }

    // 按你的要求：没选中 => Scan/Delete 都不可点
    if (this.hasBulkScanBtnTarget) this.bulkScanBtnTarget.disabled = (count === 0);
    if (this.hasBulkDeleteBtnTarget) this.bulkDeleteBtnTarget.disabled = (count === 0);
  }

  syncCheckAllState() {
    if (!this.hasCheckAllTarget) return;

    const all = this.fileChecks();
    this.checkAllTarget.checked = (all.length > 0 && all.every((x) => x.checked));
  }

  fillHiddenIds(container, ids) {
    if (!container) return;
    container.innerHTML = "";
    ids.forEach((id) => {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = "file_ids[]";
      input.value = id;
      container.appendChild(input);
    });
  }
}