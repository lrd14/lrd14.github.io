(() => {
  const STATUS_API = "https://gurp-keyauth-gateway.lrd14.workers.dev/status/public";
  const SESSION_KEY = "gurp_access_session";
  const chips = Array.from(document.querySelectorAll("[data-live-status]"));
  const accountButtons = Array.from(document.querySelectorAll("[data-account-btn]"));

  function setChipState(label, cls) {
    chips.forEach((chip) => {
      chip.textContent = label;
      chip.classList.remove("status-ok", "status-degraded", "status-down");
      chip.classList.add(cls);
    });
  }

  function getStoredSession() {
    const raw = localStorage.getItem(SESSION_KEY) || sessionStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    try {
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== "object") return null;
      return parsed;
    } catch {
      return null;
    }
  }

  function refreshAccountButton() {
    if (!accountButtons.length) return;
    const session = getStoredSession();
    const username = session && session.username ? String(session.username).trim() : "";

    accountButtons.forEach((button) => {
      if (username) {
        button.textContent = username;
        button.href = "/download";
        button.title = username;
        button.classList.add("account-name-btn");
      } else {
        button.textContent = "Login";
        button.href = "/access";
        button.removeAttribute("title");
        button.classList.remove("account-name-btn");
      }
    });
  }

  async function refreshStatus() {
    if (!chips.length) return;
    try {
      const response = await fetch(STATUS_API, { cache: "no-store" });
      const data = await response.json().catch(() => ({}));
      if (!response.ok || data.success === false) {
        throw new Error("Status unavailable");
      }

      const overall = String(data.overall || "ok");
      if (overall === "down") {
        setChipState("Some services down", "status-down");
      } else if (overall === "degraded") {
        setChipState("Partial degradation", "status-degraded");
      } else {
        setChipState("All systems operational", "status-ok");
      }
    } catch (error) {
      setChipState("Status unavailable", "status-down");
    }
  }

  refreshAccountButton();
  refreshStatus();
  setInterval(refreshAccountButton, 3000);
  setInterval(refreshStatus, 60 * 1000);
  window.addEventListener("storage", refreshAccountButton);
})();
