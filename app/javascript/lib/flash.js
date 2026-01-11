// app/javascript/lib/flash.js
// Plain JS flash behavior:
// - auto dismiss after timeout (default 5000ms, from data-flash-timeout)
// - safe with Turbo (runs on turbo:load + DOMContentLoaded)

function initFlash() {
  const nodes = Array.from(document.querySelectorAll("[data-flash]"));
  if (nodes.length === 0) return;

  nodes.forEach((el) => {
    if (el.dataset.flashInitialized === "1") return;
    el.dataset.flashInitialized = "1";

    const timeout = Number(el.dataset.flashTimeout || "2000");

    const dismiss = () => {
      if (!el.isConnected) return;
      el.remove();
    };

    window.setTimeout(dismiss, timeout);
  });
}

document.addEventListener("turbo:load", initFlash);
document.addEventListener("DOMContentLoaded", initFlash);

export default initFlash;