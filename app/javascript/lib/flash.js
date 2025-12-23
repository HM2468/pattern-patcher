// app/javascript/lib/flash.js
// Plain JS flash behavior:
// - auto dismiss after timeout (default 3000ms, from data-flash-timeout)
// - manual dismiss via [data-flash-dismiss]
// - safe with Turbo (runs on turbo:load + DOMContentLoaded)

function initFlash() {
  const nodes = Array.from(document.querySelectorAll("[data-flash]"));
  if (nodes.length === 0) return;

  nodes.forEach((el) => {
    // Avoid double-init (Turbo cache / re-render)
    if (el.dataset.flashInitialized === "1") return;
    el.dataset.flashInitialized = "1";

    const timeout = Number(el.dataset.flashTimeout || "3000");
    const dismissBtn = el.querySelector("[data-flash-dismiss]");

    const dismiss = () => {
      if (!el.isConnected) return;
      el.remove();
    };

    if (dismissBtn) {
      dismissBtn.addEventListener("click", (e) => {
        e.preventDefault();
        dismiss();
      });
    }

    // Auto dismiss
    const timer = window.setTimeout(dismiss, timeout);

    // If removed manually, clear timer
    const observer = new MutationObserver(() => {
      if (!el.isConnected) {
        window.clearTimeout(timer);
        observer.disconnect();
      }
    });
    observer.observe(document.documentElement, { childList: true, subtree: true });
  });
}

document.addEventListener("turbo:load", initFlash);
document.addEventListener("DOMContentLoaded", initFlash);

export default initFlash;