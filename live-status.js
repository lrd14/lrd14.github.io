(() => {
  const STATUS_API = "https://gurp-keyauth-gateway.lrd14.workers.dev/status/public";
  const chips = Array.from(document.querySelectorAll("[data-live-status]"));
  if (!chips.length) return;

  function setChipState(label, cls) {
    chips.forEach((chip) => {
      chip.textContent = label;
      chip.classList.remove("status-ok", "status-degraded", "status-down");
      chip.classList.add(cls);
    });
  }

  async function refreshStatus() {
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

  refreshStatus();
  setInterval(refreshStatus, 60 * 1000);
})();
