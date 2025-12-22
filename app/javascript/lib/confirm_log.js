// app/javascript/lib/pop_confirm_log.js
// Plain JS confirm modal: no turbo_stream dependency.
// Responsibilities:
// - show/hide modal
// - render title/message
// - submit the original form on confirm

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
    // Prevent default submit (e.g. button_to) and open our modal instead.
    if (event) event.preventDefault();

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
      options.confirmLabel = btn.dataset.confirmConfirmLabel; // optional
      options.cancelLabel = btn.dataset.confirmCancelLabel;   // optional
    } else if (btnOrOptions && typeof btnOrOptions === "object") {
      options = btnOrOptions;
    }

    // Find the trigger button's form; confirm() will submit it later.
    const form = btn ? btn.closest("form") : (event?.currentTarget?.closest?.("form") || null);
    if (!form) {
      console.warn("[PopConfirmLog] trigger form not found.");
      return false;
    }
    this.pendingForm = form;

    // Copy labels with sane defaults.
    title.textContent = options.title || "Confirm";
    cancel.textContent = options.cancelLabel || "Cancel";
    confirm.textContent = options.confirmLabel || "Confirm";

    // Message rendering:
    // - Prefer message_html (explicit HTML) when present
    // - Otherwise fallback to plain text message
    if (options.message_html && options.message_html.length > 0) {
      message.innerHTML = options.message_html;
    } else {
      message.textContent = options.message || "Are you sure?";
    }

    // Show modal
    root.classList.remove("hidden");
    root.setAttribute("aria-hidden", "false");

    // Make onclick="return PopConfirmLog.open(...)" stop default behavior.
    return false;
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
      // Submit the original form that triggered the modal.
      this.pendingForm.requestSubmit();
    }

    this.pendingForm = null;
    root.classList.add("hidden");
    root.setAttribute("aria-hidden", "true");
  }
};

export default PopConfirmLog;