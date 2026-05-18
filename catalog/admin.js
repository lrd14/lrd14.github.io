(() => {
  const authApi = window.GurpCatalogAuth;
  if (!authApi) return;
  const API_BASE = authApi.apiBase;
  const ADMIN_TOKEN_STORAGE_KEY = "gurp_catalog_admin_token";

  const gridEl = document.getElementById("catalogGrid");
  const listStatusEl = document.getElementById("listStatus");
  const adminAuthStatusEl = document.getElementById("adminAuthStatus");
  const adminStatusEl = document.getElementById("adminStatus");
  const searchInput = document.getElementById("searchInput");
  const typeFilter = document.getElementById("typeFilter");
  const refreshBtn = document.getElementById("refreshBtn");
  const adminTokenInput = document.getElementById("adminTokenInput");
  const saveAdminTokenBtn = document.getElementById("saveAdminTokenBtn");
  const template = document.getElementById("catalogCardTemplate");

  let sessionToken = "";
  let allItems = [];
  let imageObjectUrls = [];
  let adminToken = "";

  function setStatus(el, message, type) {
    el.textContent = message;
    el.classList.remove("error", "success");
    if (type) el.classList.add(type);
  }

  function loadAdminToken() {
    adminToken = String(localStorage.getItem(ADMIN_TOKEN_STORAGE_KEY) || "");
    adminTokenInput.value = adminToken;
    renderAdminStatus();
  }

  function saveAdminToken() {
    adminToken = String(adminTokenInput.value || "").trim();
    if (adminToken) {
      localStorage.setItem(ADMIN_TOKEN_STORAGE_KEY, adminToken);
    } else {
      localStorage.removeItem(ADMIN_TOKEN_STORAGE_KEY);
    }
    renderAdminStatus();
  }

  function renderAdminStatus() {
    if (!adminToken) {
      setStatus(adminStatusEl, "Admin token not set.", "");
      return;
    }
    setStatus(adminStatusEl, "Admin token loaded. Delete buttons are active.", "success");
  }

  function authorizedFetch(url, options = {}) {
    const headers = new Headers(options.headers || {});
    headers.set("Authorization", `Bearer ${sessionToken}`);
    return fetch(url, { ...options, headers });
  }

  function buildImageUrl(id) {
    return `${API_BASE}/catalog/public/image?id=${encodeURIComponent(id)}`;
  }

  function revokeImageUrls() {
    imageObjectUrls.forEach((url) => URL.revokeObjectURL(url));
    imageObjectUrls = [];
  }

  async function loadImageIntoElement(img, id) {
    try {
      const response = await authorizedFetch(buildImageUrl(id), { cache: "no-store" });
      if (!response.ok) throw new Error("Image unavailable");
      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      imageObjectUrls.push(objectUrl);
      img.src = objectUrl;
    } catch {
      img.removeAttribute("src");
      img.alt = "No preview available";
    }
  }

  async function handleDelete(event) {
    event.preventDefault();
    if (!adminToken) {
      setStatus(listStatusEl, "Set admin token first.", "error");
      return;
    }
    const button = event.currentTarget;
    const id = String(button.dataset.id || "");
    const title = String(button.dataset.title || id);
    if (!id) return;

    if (!window.confirm(`Delete "${title}"? This cannot be undone.`)) {
      return;
    }

    const original = button.textContent;
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
      setStatus(listStatusEl, `"${title}" removed.`, "success");
      await loadCatalog();
    } catch (error) {
      setStatus(listStatusEl, error.message || "Delete failed.", "error");
      button.textContent = original;
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
      const source = `${item.title || ""} ${item.author || ""} ${item.description || ""}`.toLowerCase();
      return source.includes(term);
    });

    revokeImageUrls();
    gridEl.innerHTML = "";
    if (!filtered.length) {
      setStatus(listStatusEl, "No uploads match this filter.", "");
      return;
    }

    setStatus(listStatusEl, `${filtered.length} upload${filtered.length === 1 ? "" : "s"} shown.`, "");
    filtered.forEach((item) => {
      const fragment = template.content.cloneNode(true);
      const img = fragment.querySelector(".preview");
      const title = fragment.querySelector("h3");
      const badge = fragment.querySelector(".badge");
      const description = fragment.querySelector(".description");
      const meta = fragment.querySelector(".meta");
      const deleteButton = fragment.querySelector(".delete-link");

      title.textContent = String(item.title || "Untitled");
      badge.textContent = String(item.type || "item").toUpperCase();
      description.textContent = String(item.description || "No description.");
      const created = new Date(item.createdAt);
      const createdText = Number.isFinite(created.getTime()) ? created.toLocaleString() : "unknown date";
      meta.textContent = `by ${String(item.author || "anonymous")} • ${createdText} • downloads: ${Number(item.downloads || 0)}`;

      img.alt = `${String(item.title || "Upload")} preview`;
      img.loading = "lazy";
      loadImageIntoElement(img, item.id);

      deleteButton.dataset.id = String(item.id || "");
      deleteButton.dataset.title = String(item.title || item.id || "item");
      deleteButton.addEventListener("click", handleDelete);
      gridEl.appendChild(fragment);
    });
  }

  async function loadCatalog() {
    setStatus(listStatusEl, "Loading uploads...", "");
    try {
      const response = await authorizedFetch(`${API_BASE}/catalog/public/list`, { cache: "no-store" });
      const data = await response.json().catch(() => ({}));
      if (!response.ok || !data.success || !Array.isArray(data.items)) {
        throw new Error(data.message || "Could not load uploads.");
      }
      allItems = data.items;
      renderCards();
    } catch (error) {
      setStatus(listStatusEl, error.message || "Could not load uploads.", "error");
      gridEl.innerHTML = "";
    }
  }

  saveAdminTokenBtn.addEventListener("click", saveAdminToken);
  adminTokenInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      saveAdminToken();
    }
  });
  searchInput.addEventListener("input", renderCards);
  typeFilter.addEventListener("change", renderCards);
  refreshBtn.addEventListener("click", loadCatalog);
  window.addEventListener("beforeunload", revokeImageUrls);

  loadAdminToken();
  authApi
    .requireCatalogSession({ redirectOnFail: false })
    .then((session) => {
      sessionToken = String(session.token || "");
      adminAuthStatusEl.textContent = `Logged in as ${String(session.username || "user")}`;
      loadCatalog();
    })
    .catch((error) => {
      setStatus(listStatusEl, error.message || "Login required.", "error");
      adminAuthStatusEl.innerHTML = "";
      const link = document.createElement("a");
      link.href = authApi.buildAccessUrl(window.location.href);
      link.textContent = "Login on gurp.cc to access admin page";
      link.className = "upload-pill";
      adminAuthStatusEl.appendChild(link);
    });
})();
