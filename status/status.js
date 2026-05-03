async function loadStatus() {
  const overallTitle = document.getElementById("overallTitle");
  const overallText = document.getElementById("overallText");
  const overallPill = document.getElementById("overallPill");
  const servicesEl = document.getElementById("services");
  const incidentsEl = document.getElementById("incidents");
  const updatedAtEl = document.getElementById("updatedAt");

  try {
    const response = await fetch("data.json", { cache: "no-store" });
    const data = await response.json();

    const services = Array.isArray(data.services) ? data.services : [];
    const incidents = Array.isArray(data.incidents) ? data.incidents : [];

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

    updatedAtEl.textContent = `Updated: ${data.updatedAt || "Unknown"}`;

    servicesEl.innerHTML = services
      .map(
        (s) => `
        <article class="service">
          <div class="service-head">
            <h3>${escapeHtml(s.name || "Service")}</h3>
            <span class="badge ${escapeHtml(s.status || "ok")}">${labelForStatus(s.status)}</span>
          </div>
          <p>${escapeHtml(s.detail || "No details available.")}</p>
        </article>
      `
      )
      .join("");

    incidentsEl.innerHTML = incidents.length
      ? incidents.map((entry) => `<li>${escapeHtml(entry)}</li>`).join("")
      : "<li>No active incidents.</li>";
  } catch (error) {
    overallTitle.textContent = "Status unavailable";
    overallPill.textContent = "Status unavailable";
    overallPill.className = "overall-pill badge down";
    overallText.textContent = "Could not load status data.";
    servicesEl.innerHTML = "";
    incidentsEl.innerHTML = "<li>Unable to fetch incident feed.</li>";
    updatedAtEl.textContent = "Updated: --";
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

loadStatus();
