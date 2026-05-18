(() => {
  const authApi = window.GurpCatalogAuth;
  if (!authApi) return;
  const API_BASE = authApi.apiBase;
  const gridEl = document.getElementById("catalogGrid");
  const listStatusEl = document.getElementById("listStatus");
  const authStatusEl = document.getElementById("authStatus");
  const searchInput = document.getElementById("searchInput");
  const typeFilter = document.getElementById("typeFilter");
  const refreshBtn = document.getElementById("refreshBtn");
  const adminTokenInput = document.getElementById("adminTokenInput");
  const saveAdminTokenBtn = document.getElementById("saveAdminTokenBtn");
  const adminStatusEl = document.getElementById("adminStatus");
  const template = document.getElementById("catalogCardTemplate");
  const ADMIN_TOKEN_STORAGE_KEY = "gurp_catalog_admin_token";

  let sessionToken = "";
  let allItems = [];
  let imageObjectUrls = [];
  let adminToken = "";

  function setStatus(el, message, type) {
    el.textContent = message;
    el.classList.remove("error", "success");
    if (type) {
      el.classList.add(type);
    }
  }

  function escapeText(value) {
    return String(value || "").replace(/\s+/g, " ").trim();
  }

  function formatDate(value) {
    const d = new Date(value);
    if (!Number.isFinite(d.getTime())) return "unknown date";
    return d.toLocaleString();
  }

  function buildDownloadUrl(id) {
    return `${API_BASE}/catalog/public/download?id=${encodeURIComponent(id)}`;
  }

  function buildImageUrl(id) {
    return `${API_BASE}/catalog/public/image?id=${encodeURIComponent(id)}`;
  }

  function loadAdminToken() {
    adminToken = String(localStorage.getItem(ADMIN_TOKEN_STORAGE_KEY) || "");
    if (adminTokenInput) adminTokenInput.value = adminToken;
    renderAdminState();
  }

  function saveAdminToken() {
    adminToken = String((adminTokenInput && adminTokenInput.value) || "").trim();
    if (adminToken) {
      localStorage.setItem(ADMIN_TOKEN_STORAGE_KEY, adminToken);
    } else {
      localStorage.removeItem(ADMIN_TOKEN_STORAGE_KEY);
    }
    renderAdminState();
    renderCards();
  }

  function renderAdminState() {
    if (!adminStatusEl) return;
    if (!adminToken) {
      setStatus(adminStatusEl, "Admin tools are off.", "");
      return;
    }
    setStatus(adminStatusEl, "Admin tools are enabled. Delete buttons are visible.", "success");
  }

  function authorizedFetch(url, options = {}) {
    const headers = new Headers(options.headers || {});
    headers.set("Authorization", `Bearer ${sessionToken}`);
    return fetch(url, { ...options, headers });
  }

  function revokeImageUrls() {
    imageObjectUrls.forEach((url) => URL.revokeObjectURL(url));
    imageObjectUrls = [];
  }

  async function loadImageIntoElement(img, id) {
    try {
      const response = await authorizedFetch(buildImageUrl(id), { cache: "no-store" });
      if (!response.ok) {
        throw new Error("Image unavailable");
      }
      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      imageObjectUrls.push(objectUrl);
      img.src = objectUrl;
    } catch {
      img.removeAttribute("src");
      img.alt = "No preview available";
    }
  }

  async function handleDownload(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const id = String(button.dataset.id || "");
    if (!id) return;
    const originalText = button.textContent;
    button.textContent = "Preparing...";
    button.classList.add("disabled");
    try {
      const response = await authorizedFetch(buildDownloadUrl(id), { cache: "no-store" });
      if (!response.ok) {
        const text = await response.text().catch(() => "");
        throw new Error(text || "Download did not go through. Try again.");
      }
      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      const link = document.createElement("a");
      const fileName = String(response.headers.get("content-disposition") || "")
        .match(/filename="([^"]+)"/i)?.[1] || "download.bin";
      link.href = objectUrl;
      link.download = fileName;
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(objectUrl);
      button.textContent = "Download";
      await loadCatalog();
    } catch (error) {
      setStatus(listStatusEl, error.message || "Download did not go through. Try again.", "error");
      button.textContent = originalText;
    } finally {
      button.classList.remove("disabled");
    }
  }

  async function handleDelete(event) {
    event.preventDefault();
    const button = event.currentTarget;
    const id = String(button.dataset.id || "");
    if (!id || !adminToken) return;
    const item = allItems.find((x) => String(x.id || "") === id);
    const title = item && item.title ? item.title : id;
    const confirmed = window.confirm(`Delete "${title}" from catalog? This cannot be undone.`);
    if (!confirmed) return;

    const originalText = button.textContent;
    button.textContent = "Deleting...";
    button.classList.add("disabled");
    try {
      const response = await authorizedFetch(`${API_BASE}/catalog/admin/delete`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id, adminToken })
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok || !data.success) {
        throw new Error(data.message || "Delete failed.");
      }
      setStatus(listStatusEl, `"${title}" was removed.`, "success");
      await loadCatalog();
    } catch (error) {
      setStatus(listStatusEl, error.message || "Delete failed.", "error");
      button.textContent = originalText;
    } finally {
      button.classList.remove("disabled");
    }
  }

  function renderCards() {
    const term = String(searchInput.value || "").trim().toLowerCase();
    const selectedType = String(typeFilter.value || "all").toLowerCase();
    const filtered = allItems.filter((item) => {
      const typeOk = selectedType === "all" || item.type === selectedType;
      if (!typeOk) return false;

      if (!term) return true;
      const source = `${item.title || ""} ${item.description || ""} ${item.author || ""} ${item.type || ""}`.toLowerCase();
      return source.includes(term);
    });

    revokeImageUrls();
    gridEl.innerHTML = "";
    if (!filtered.length) {
      setStatus(listStatusEl, "No uploads match this filter yet.", "");
      return;
    }

    setStatus(listStatusEl, `${filtered.length} upload${filtered.length === 1 ? "" : "s"} shown.`, "");
    filtered.forEach((item) => {
      const fragment = template.content.cloneNode(true);
      const root = fragment.querySelector(".catalog-card");
      const img = fragment.querySelector(".preview");
      const title = fragment.querySelector("h3");
      const badge = fragment.querySelector(".badge");
      const description = fragment.querySelector(".description");
      const meta = fragment.querySelector(".meta");
      const downloadLink = fragment.querySelector(".download-link");
      const deleteButton = fragment.querySelector(".delete-link");

      const safeTitle = escapeText(item.title) || "Untitled";
      const safeDescription = escapeText(item.description) || "No description.";
      const safeType = (item.type || "item").toUpperCase();

      title.textContent = safeTitle;
      badge.textContent = safeType;
      description.textContent = safeDescription;
      meta.textContent = `by ${escapeText(item.author) || "anonymous"} • ${formatDate(item.createdAt)} • downloads: ${Number(item.downloads || 0)}`;

      img.alt = `${safeTitle} preview`;
      img.loading = "lazy";
      loadImageIntoElement(img, item.id);

      downloadLink.href = "#";
      downloadLink.dataset.id = item.id;
      downloadLink.textContent = "Download";
      downloadLink.addEventListener("click", handleDownload);

      if (adminToken) {
        deleteButton.hidden = false;
        deleteButton.dataset.id = item.id;
        deleteButton.textContent = "Delete";
        deleteButton.addEventListener("click", handleDelete);
      } else {
        deleteButton.hidden = true;
      }

      root.dataset.id = item.id;
      gridEl.appendChild(fragment);
    });
  }

  async function loadCatalog() {
    setStatus(listStatusEl, "Loading uploads...", "");
    try {
      const response = await authorizedFetch(`${API_BASE}/catalog/public/list`, { cache: "no-store" });
      const data = await response.json().catch(() => ({}));
      if (!response.ok || !data.success || !Array.isArray(data.items)) {
        throw new Error(data.message || "Could not load uploads right now.");
      }
      allItems = data.items;
      renderCards();
    } catch (error) {
      setStatus(listStatusEl, error.message || "Could not load uploads right now.", "error");
      gridEl.innerHTML = "";
    }
  }

  searchInput.addEventListener("input", renderCards);
  typeFilter.addEventListener("change", renderCards);
  refreshBtn.addEventListener("click", loadCatalog);
  if (saveAdminTokenBtn) {
    saveAdminTokenBtn.addEventListener("click", saveAdminToken);
  }
  if (adminTokenInput) {
    adminTokenInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        saveAdminToken();
      }
    });
  }
  window.addEventListener("beforeunload", revokeImageUrls);
  loadAdminToken();

  authApi
    .requireCatalogSession({ redirectOnFail: false })
    .then((session) => {
      sessionToken = String(session.token || "");
      if (authStatusEl) {
        authStatusEl.textContent = `Logged in as ${String(session.username || "user")}`;
      }
      loadCatalog();
    })
    .catch((error) => {
      setStatus(listStatusEl, error.message || "Login required.", "error");
      if (authStatusEl) {
        authStatusEl.innerHTML = "";
        const link = document.createElement("a");
        link.href = authApi.buildAccessUrl(window.location.href);
        link.textContent = "Login on gurp.cc to open catalog";
        link.className = "upload-pill";
        authStatusEl.appendChild(link);
      }
    });
})();
