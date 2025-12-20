// app/javascript/lib/pop_confirm_log.js
// 纯 JS：不依赖 turbo_stream，只负责 show/hide + 执行动作（提交原 form）

const PopConfirmLog = {
  pendingForm: null,

  _els() {
    return {
      root: document.getElementById("app_confirm_log"),
      title: document.getElementById("app_confirm_log_title"),
      message: document.getElementById("app_confirm_log_message"),
      cancel: document.getElementById("app_confirm_log_cancel"),
      confirm: document.getElementById("app_confirm_log_confirm"),
    };
  },

  open(event, btnOrOptions) {
    // 让 button_to 的默认提交停下来
    if (event) event.preventDefault();

    const { root, title, message, cancel, confirm } = this._els();
    if (!root) {
      console.warn("[PopConfirmLog] modal root not found. Did you render shared/_confirm_log?");
      return false;
    }

    // 支持两种调用方式：
    // 1) PopConfirmLog(event, this) 通过 button 的 dataset 传参
    // 2) PopConfirmLog(event, { message: "...", title: "...", confirmLabel: "..." })
    let options = {};
    let btn = null;

    if (btnOrOptions && btnOrOptions.tagName) {
      btn = btnOrOptions;
      options.title = btn.dataset.confirmTitle;
      options.message = btn.dataset.confirmMessage;
      options.confirmLabel = btn.dataset.confirmConfirmLabel; // 可选
      options.cancelLabel = btn.dataset.confirmCancelLabel;   // 可选
    } else if (btnOrOptions && typeof btnOrOptions === "object") {
      options = btnOrOptions;
    }

    // 找到触发按钮所属的 form，稍后 Confirm 时提交它
    const form = btn ? btn.closest("form") : (event?.currentTarget?.closest?.("form") || null);
    if (!form) {
      console.warn("[PopConfirmLog] trigger form not found.");
      return false;
    }
    this.pendingForm = form;

    // 文案（默认 Cancel/Confirm）
    title.textContent = options.title || "Confirm";
    message.textContent = options.message || "Are you sure?";
    cancel.textContent = options.cancelLabel || "Cancel";
    confirm.textContent = options.confirmLabel || "Confirm";

    // show
    root.classList.remove("hidden");
    root.setAttribute("aria-hidden", "false");
    return false; // ✅ 让 onclick="return PopConfirmLog(...)" 阻止默认行为
  },

  cancel() {
    const { root } = this._els();
    if (!root) return;

    this.pendingForm = null;
    root.classList.add("hidden");
    root.setAttribute("aria-hidden", "true");
  },

  confirm() {
    const { root } = this._els();
    if (!root) return;

    if (this.pendingForm) {
      // ✅ 执行“弹窗弹出之前的动作”：提交原 form（也就是 delete）
      this.pendingForm.requestSubmit();
    }

    this.pendingForm = null;
    root.classList.add("hidden");
    root.setAttribute("aria-hidden", "true");
  }
};

export default PopConfirmLog;