// app/javascript/lib/confirm_log.js

const PopConfirmLog = {
  pendingForm: null,
  lastTriggerEl: null,
  _bound: false,

  _els() {
    return {
      root: document.getElementById("app_confirm_log"),
      title: document.getElementById("app_confirm_log_title"),
      message: document.getElementById("app_confirm_log_message"),
      cancel: document.getElementById("app_confirm_log_cancel"),
      confirm: document.getElementById("app_confirm_log_confirm"),
    };
  },

  _ensureBindings() {
    if (this._bound) return;
    this._bound = true;

    // When Turbo finishes the form submission, close modal (success only).
    // This prevents "modal hides too early" and also works even if submit triggers navigation.
    document.addEventListener("turbo:submit-end", (e) => {
      if (!this.pendingForm) return;
      if (e.target !== this.pendingForm) return;

      // e.detail.success is true for 2xx/3xx responses
      if (e.detail && e.detail.success) {
        this._hideModal();
      }
    });
  },

  open(event, btnOrOptions) {
    if (event) event.preventDefault();
    this._ensureBindings();

    const { root, title, message, cancel, confirm } = this._els();
    if (!root) {
      console.warn("[PopConfirmLog] modal root not found. Did you render shared/_confirm_log?");
      return false;
    }

    // Supports two calling styles:
    // 1) PopConfirmLog.open(event, this) -> read options from button dataset
    // 2) PopConfirmLog.open(event, { ...options }) -> pass options directly
    let options = {};
    let btn = null;

    if (btnOrOptions && btnOrOptions.tagName) {
      btn = btnOrOptions;
      // Dataset keys map:
      // data-confirm-title              -> dataset.confirmTitle
      // data-confirm-message            -> dataset.confirmMessage
      // data-confirm-message-html       -> dataset.confirmMessageHtml
      // data-confirm-confirm-label      -> dataset.confirmConfirmLabel
      // data-confirm-cancel-label       -> dataset.confirmCancelLabel
      options.title = btn.dataset.confirmTitle;
      options.message = btn.dataset.confirmMessage;
      options.message_html = btn.dataset.confirmMessageHtml;
      options.confirmLabel = btn.dataset.confirmConfirmLabel;
      options.cancelLabel = btn.dataset.confirmCancelLabel;
    } else if (btnOrOptions && typeof btnOrOptions === "object") {
      options = btnOrOptions;
    }

    const form = btn ? btn.closest("form") : (event?.currentTarget?.closest?.("form") || null);
    if (!form) {
      console.warn("[PopConfirmLog] trigger form not found.");
      return false;
    }

    // Remember for later restore-focus
    this.pendingForm = form;
    this.lastTriggerEl = btn || document.activeElement;

    title.textContent = options.title || "Confirm";
    cancel.textContent = options.cancelLabel || "Cancel";
    confirm.textContent = options.confirmLabel || "Confirm";

    if (options.message_html && options.message_html.length > 0) {
      message.innerHTML = options.message_html;
    } else {
      message.textContent = options.message || "Are you sure?";
    }

    // Show modal: remove hidden + remove inert + aria-hidden=false
    root.classList.remove("hidden");
    root.setAttribute("aria-hidden", "false");
    root.inert = false;

    // Focus confirm button (OK because modal is visible now)
    confirm?.focus({ preventScroll: true });

    return false;
  },

  cancel() {
    this._hideModal();
  },

  confirm() {
    const { root } = this._els();
    if (!root) return;

    if (this.pendingForm) {
      // Submit the original form. Turbo will handle navigation.
      this.pendingForm.requestSubmit();
      // Do NOT immediately hide here; let turbo:submit-end close it on success.
      // (If you hide immediately you risk focus/aria-hidden timing issues + you may hide on failed requests)
      return;
    }

    this._hideModal();
  },

  _hideModal() {
    const { root } = this._els();
    if (!root) return;

    // Critical: move focus OUT before hiding / aria-hidden=true
    const active = document.activeElement;
    if (active && root.contains(active)) {
      active.blur();
    }

    // Hide
    root.classList.add("hidden");
    root.setAttribute("aria-hidden", "true");
    root.inert = true;

    // Restore focus to trigger element (best practice)
    if (this.lastTriggerEl && typeof this.lastTriggerEl.focus === "function") {
      this.lastTriggerEl.focus({ preventScroll: true });
    }

    this.pendingForm = null;
    this.lastTriggerEl = null;
  },
};

window.PopConfirmLog = PopConfirmLog;
export default PopConfirmLog;