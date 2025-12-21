// app/javascript/lexical_pattern_test_page.js
(function () {
  function byId(id) { return document.getElementById(id); }

  function escapeHtml(s) {
    return String(s)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute("content") : "";
  }

  function injectStyleOnce() {
    if (document.getElementById("lp-match-style")) return;

    const style = document.createElement("style");
    style.id = "lp-match-style";
    style.textContent = `
      #test_editor:empty:before {
        content: attr(data-placeholder);
        color: #9ca3af;
      }
      .lp-match { background: #fde68a; border-radius: 3px; padding: 0 2px; }
      .lp-match-active { outline: 2px solid #f59e0b; background: #fbbf24; }
    `;
    document.head.appendChild(style);
  }

  // Build highlighted HTML by sequentially finding each returned match from cursor.
  // First version: does not handle overlapping matches; items not found are skipped.
  function buildHighlightedHtml(text, matches) {
    let cursor = 0;
    let html = "";

    for (const m of matches) {
      if (!m) continue;

      const idx = text.indexOf(m, cursor);
      if (idx === -1) continue;

      const start = idx;
      const end = idx + m.length;

      html += escapeHtml(text.slice(cursor, start));
      html += `<span class="lp-match" data-start="${start}" data-end="${end}">${escapeHtml(m)}</span>`;
      cursor = end;
    }

    html += escapeHtml(text.slice(cursor));
    return html;
  }

  function setNavEnabled(prevBtn, nextBtn, enabled) {
    prevBtn.disabled = !enabled;
    nextBtn.disabled = !enabled;
  }

  // Only scroll inside the editor (not the whole page)
  function scrollIntoEditorView(editor, el) {
    const editorRect = editor.getBoundingClientRect();
    const elRect = el.getBoundingClientRect();

    const topVisible = editor.scrollTop;
    const bottomVisible = topVisible + editor.clientHeight;

    // element position in editor's scroll coordinate system
    const elTop = (elRect.top - editorRect.top) + editor.scrollTop;
    const elBottom = elTop + elRect.height;

    const padding = 24;

    if (elTop < topVisible + padding) {
      editor.scrollTop = Math.max(0, elTop - padding);
    } else if (elBottom > bottomVisible - padding) {
      editor.scrollTop = elBottom - editor.clientHeight + padding;
    }
  }

  function focusMatch(editor, matchEls, idx) {
    matchEls.forEach(el => el.classList.remove("lp-match-active"));
    const el = matchEls[idx];
    if (!el) return;

    el.classList.add("lp-match-active");
    scrollIntoEditorView(editor, el);
  }

  async function run() {
    injectStyleOnce();

    // Always locate by id (robust against class changes)
    const editor  = byId("test_editor");
    const scanBtn = byId("scan_btn");
    const prevBtn = byId("prev_btn");
    const nextBtn = byId("next_btn");
    const stat    = byId("match_stat");
    const errBox  = byId("scan_error");

    if (!editor || !scanBtn || !prevBtn || !nextBtn || !stat || !errBox) return;
    if (!window.RegexTestPage || !window.RegexTestPage.runTestUrl) return;

    let currentIndex = 0;
    let matchEls = [];

    function showError(msg) {
      errBox.textContent = msg;
      errBox.classList.remove("hidden");
    }

    function clearError() {
      errBox.textContent = "";
      errBox.classList.add("hidden");
    }

    async function handleScan() {
      clearError();
      stat.textContent = "Scanning...";
      setNavEnabled(prevBtn, nextBtn, false);

      const text = (editor.innerText || "").replace(/\r\n/g, "\n");
      const url = window.RegexTestPage.runTestUrl;

      try {
        const resp = await fetch(url, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-CSRF-Token": csrfToken()
          },
          body: JSON.stringify({ test_content: text })
        });

        const data = await resp.json().catch(() => ({}));

        if (!resp.ok) {
          const msg = data && data.error ? data.error : `Request failed: ${resp.status}`;
          showError(msg);
          stat.textContent = "Scan failed";
          return;
        }

        const st = Array.isArray(data.st) ? data.st : [];

        if (st.length === 0) {
          editor.textContent = text;
          matchEls = [];
          currentIndex = 0;
          stat.textContent = "No matches";
          return;
        }

        editor.innerHTML = buildHighlightedHtml(text, st);
        matchEls = Array.from(editor.querySelectorAll(".lp-match"));

        if (matchEls.length === 0) {
          editor.textContent = text;
          stat.textContent = `Matches returned: ${st.length}, but could not locate in text`;
          setNavEnabled(prevBtn, nextBtn, false);
          return;
        }

        currentIndex = 0;
        setNavEnabled(prevBtn, nextBtn, true);
        stat.textContent = `Match 1 / ${matchEls.length}`;
        focusMatch(editor, matchEls, currentIndex);
      } catch (e) {
        showError(`Network error: ${e.message || String(e)}`);
        stat.textContent = "Scan failed";
      }
    }

    function handlePrev() {
      if (!matchEls.length) return;
      currentIndex = (currentIndex - 1 + matchEls.length) % matchEls.length;
      stat.textContent = `Match ${currentIndex + 1} / ${matchEls.length}`;
      focusMatch(editor, matchEls, currentIndex);
    }

    function handleNext() {
      if (!matchEls.length) return;
      currentIndex = (currentIndex + 1) % matchEls.length;
      stat.textContent = `Match ${currentIndex + 1} / ${matchEls.length}`;
      focusMatch(editor, matchEls, currentIndex);
    }

    // ✅ bind events by id
    scanBtn.addEventListener("click", handleScan);
    prevBtn.addEventListener("click", handlePrev);
    nextBtn.addEventListener("click", handleNext);

    // Optional: click on highlight to jump
    editor.addEventListener("click", (ev) => {
      const hit = ev.target.closest(".lp-match");
      if (!hit) return;

      const idx = matchEls.indexOf(hit);
      if (idx < 0) return;

      currentIndex = idx;
      stat.textContent = `Match ${currentIndex + 1} / ${matchEls.length}`;
      focusMatch(editor, matchEls, currentIndex);
    });

    // Optional: Ctrl/Cmd+Enter triggers scan
    editor.addEventListener("keydown", (ev) => {
      if ((ev.ctrlKey || ev.metaKey) && ev.key === "Enter") {
        ev.preventDefault();
        handleScan();
      }
    });
  }

  document.addEventListener("DOMContentLoaded", run);
})();