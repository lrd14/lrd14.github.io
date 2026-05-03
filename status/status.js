async function loadStatus() {
  const STATUS_API_BASE = "https://gurp-keyauth-gateway.lrd14.workers.dev/status";
  const overallTitle = document.getElementById("overallTitle");
  const overallText = document.getElementById("overallText");
  const overallPill = document.getElementById("overallPill");
  const servicesEl = document.getElementById("services");
  const incidentsEl = document.getElementById("incidents");
  const updatedAtEl = document.getElementById("updatedAt");
  const historyEl = document.getElementById("history");
  const footerUpdatedAtEl = document.getElementById("footerUpdatedAt");
  const nextRefreshInEl = document.getElementById("nextRefreshIn");

  if (!window.__statusRefreshState) {
    window.__statusRefreshState = {
      nextRefreshAt: Date.now() + 60_000,
      countdownStarted: false
    };
  }
  const refreshState = window.__statusRefreshState;

  if (!refreshState.countdownStarted) {
    refreshState.countdownStarted = true;
    setInterval(() => {
      const msLeft = Math.max(0, refreshState.nextRefreshAt - Date.now());
      nextRefreshInEl.textContent = formatCountdown(msLeft);
    }, 1000);
  }

  try {
    const response = await fetch(`${STATUS_API_BASE}/public`, { cache: "no-store" });
    const data = await response.json();

    const services = Array.isArray(data.services) ? data.services : [];
    const incidents = Array.isArray(data.incidents) ? data.incidents : [];
    const history = Array.isArray(data.history) ? data.history : [];

    let overall = "ok";
    if (services.some((s) => s.status === "down")) overall = "down";
    else if (services.some((s) => s.status === "degraded")) overall = "degraded";
    if (typeof data.overall === "string") {
      overall = data.overall;
    }

    const overallTitleText = {
      ok: "All systems operational",
      degraded: "Partial service degradation",
      down: "Major service outage"
    }[overall] || "Status unavailable";

    const overallLabel = {
      ok: "Operational",
      degraded: "Degraded",
      down: "Outage"
    }[overall];

    overallTitle.textContent = overallTitleText;
    overallPill.textContent = overallLabel;
    overallPill.className = `overall-pill badge ${overall}`;
    overallText.textContent = data.message || "Live status for gurp services.";

    const updatedAtText = data.updatedAt || "Unknown";
    updatedAtEl.textContent = `Updated: ${updatedAtText}`;
    footerUpdatedAtEl.textContent = updatedAtText;

    const timelineEvents = buildTimelineEvents(services, history);

    servicesEl.innerHTML = services
      .map(
        (s) => `
        <article class="service">
          <div class="service-head">
            <h3>${escapeHtml(s.name || "Service")}</h3>
            <span class="badge ${escapeHtml(s.status || "ok")}">${labelForStatus(s.status)}</span>
          </div>
          <p>${escapeHtml(s.detail || "No details available.")}</p>
          <div class="service-bars-wrap">
            <div class="service-bars">
              ${renderServiceBars(s.name || "Service", timelineEvents)}
            </div>
            <div class="service-bars-labels">
              <span>60m</span>
              <span>now</span>
            </div>
          </div>
        </article>
      `
      )
      .join("");

    incidentsEl.innerHTML = incidents.length
      ? incidents.map((entry) => `<li>${escapeHtml(entry)}</li>`).join("")
      : "<li>No active incidents.</li>";

    historyEl.innerHTML = history.length
      ? history
          .slice(0, 15)
          .map(
            (entry) =>
              `<li><strong>${escapeHtml(entry.ts || "Unknown time")}</strong> - ${escapeHtml(
                entry.message || "Status update"
              )} (${labelForStatus(entry.overall || "ok")})</li>`
          )
          .join("")
      : "<li>No recorded history yet.</li>";
  } catch (error) {
    overallTitle.textContent = "Status unavailable";
    overallPill.textContent = "Status unavailable";
    overallPill.className = "overall-pill badge down";
    overallText.textContent = "Could not load status data.";
    servicesEl.innerHTML = "";
    incidentsEl.innerHTML = "<li>Unable to fetch incident feed.</li>";
    historyEl.innerHTML = "<li>Unable to fetch history feed.</li>";
    updatedAtEl.textContent = "Updated: --";
    footerUpdatedAtEl.textContent = "--";
  } finally {
    refreshState.nextRefreshAt = Date.now() + 60_000;
  }
}

function labelForStatus(status) {
  if (status === "down") return "Down";
  if (status === "degraded") return "Degraded";
  return "Operational";
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatCountdown(msLeft) {
  const totalSeconds = Math.ceil(msLeft / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function renderServiceBars(serviceName, events) {
  const totalBars = 60;
  const slotMs = 60 * 1000;
  const now = Date.now();
  const startTime = now - totalBars * slotMs;
  const bars = [];

  for (let i = 0; i < totalBars; i += 1) {
    const timePoint = startTime + i * slotMs;
    const status = statusAtTime(serviceName, timePoint, events);
    const title = `${serviceName} ${labelForStatus(status)} at ${formatShortTime(timePoint)}`;
    bars.push(`<span class="uptime-bar ${status}" title="${escapeHtmlAttr(title)}"></span>`);
  }

  return bars.join("");
}

function buildTimelineEvents(currentServices, history) {
  const events = [];
  const nowIso = new Date().toISOString();
  events.push({
    ts: nowIso,
    services: currentServices.map((svc) => ({
      name: String(svc.name || ""),
      status: normalizeStatus(String(svc.status || "ok"))
    }))
  });

  for (const entry of history) {
    if (!entry || !entry.ts || !Array.isArray(entry.services)) continue;
    events.push({
      ts: entry.ts,
      services: entry.services.map((svc) => ({
        name: String(svc.name || ""),
        status: normalizeStatus(String(svc.status || "ok"))
      }))
    });
  }

  return events
    .map((event) => ({
      ...event,
      timeMs: parseStatusTime(event.ts)
    }))
    .filter((event) => Number.isFinite(event.timeMs))
    .sort((a, b) => b.timeMs - a.timeMs);
}

function statusAtTime(serviceName, timeMs, events) {
  const target = String(serviceName || "").toLowerCase();
  for (const event of events) {
    if (event.timeMs > timeMs) continue;
    const service = event.services.find((svc) => String(svc.name || "").toLowerCase() === target);
    if (service) {
      return normalizeStatus(service.status);
    }
  }
  return "ok";
}

function parseStatusTime(value) {
  if (!value) return NaN;
  const str = String(value).trim();
  if (str.endsWith(" UTC")) {
    const withoutUtc = str.slice(0, -4).replace(" ", "T");
    return Date.parse(`${withoutUtc}Z`);
  }
  return Date.parse(str);
}

function normalizeStatus(status) {
  if (status === "down") return "down";
  if (status === "degraded") return "degraded";
  return "ok";
}

function escapeHtmlAttr(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatShortTime(timeMs) {
  return new Date(timeMs).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

loadStatus();
setInterval(loadStatus, 60 * 1000);
