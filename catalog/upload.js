(() => {
  const authApi = window.GurpCatalogAuth;
  if (!authApi) return;
  const API_BASE = authApi.apiBase;
  const uploadForm = document.getElementById("uploadForm");
  const uploadStatusEl = document.getElementById("uploadStatus");
  const authStatusEl = document.getElementById("uploadAuthStatus");
  const typeInput = document.getElementById("typeInput");
  const fileInput = document.getElementById("fileInput");
  const fileTypeHint = document.getElementById("fileTypeHint");
  const TURNSTILE_SITE_KEY = "0x4AAAAAADIfjLRkCogM7-dm";
  const MAX_FILE_BYTES = 1 * 1024 * 1024;
  const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
  let sessionToken = "";
  let turnstileId = null;

  function setStatus(message, type) {
    uploadStatusEl.textContent = message;
    uploadStatusEl.classList.remove("error", "success");
    if (type) uploadStatusEl.classList.add(type);
  }

  function renderTurnstile() {
    if (!window.turnstile || turnstileId !== null) return;
    turnstileId = window.turnstile.render("#uploadTurnstile", {
      sitekey: TURNSTILE_SITE_KEY,
      theme: "dark"
    });
  }

  function getTurnstileToken() {
    if (!window.turnstile || turnstileId === null) return "";
    return String(window.turnstile.getResponse(turnstileId) || "");
  }

  function updateFileConstraints() {
    const type = String(typeInput.value || "config").toLowerCase();
    if (type === "lua") {
      fileInput.accept = ".lua";
      if (fileTypeHint) fileTypeHint.textContent = "Lua requires .lua files (max 1MB).";
    } else {
      fileInput.accept = ".gurp";
      if (fileTypeHint) fileTypeHint.textContent = "Config requires .gurp files (max 1MB).";
    }
  }

  async function submitUpload(event) {
    event.preventDefault();
    const formData = new FormData(uploadForm);
    const type = String(formData.get("type") || "").trim().toLowerCase();
    const title = String(formData.get("title") || "").trim();
    const description = String(formData.get("description") || "").trim();
    const file = formData.get("file");
    const image = formData.get("image");
    const turnstileToken = getTurnstileToken();

    if (!title || !description) {
      setStatus("Title and description are required.", "error");
      return;
    }
    if (!(file instanceof File) || file.size <= 0) {
      setStatus("Please choose a file to upload.", "error");
      return;
    }
    const name = String(file.name || "").toLowerCase();
    if (type === "lua" && !name.endsWith(".lua")) {
      setStatus("Lua uploads must use .lua files.", "error");
      return;
    }
    if (type === "config" && !name.endsWith(".gurp")) {
      setStatus("Config uploads must use .gurp files.", "error");
      return;
    }
    if (file.size > MAX_FILE_BYTES) {
      setStatus("File is too large (max 1MB).", "error");
      return;
    }
    if (!(image instanceof File) || image.size <= 0) {
      setStatus("Please choose a preview image.", "error");
      return;
    }
    if (image.size > MAX_IMAGE_BYTES) {
      setStatus("Image is too large (max 5MB).", "error");
      return;
    }
    if (!turnstileToken) {
      setStatus("Please complete Cloudflare verification.", "error");
      return;
    }

    formData.set("turnstileToken", turnstileToken);

    setStatus("Uploading entry...", "");
    try {
      const response = await fetch(`${API_BASE}/catalog/upload`, {
        method: "POST",
        headers: { Authorization: `Bearer ${sessionToken}` },
        body: formData
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok || !data.success) {
        throw new Error(data.message || "Upload failed.");
      }
      setStatus("Upload successful. View it in the catalog now.", "success");
      uploadForm.reset();
      if (window.turnstile && turnstileId !== null) {
        window.turnstile.reset(turnstileId);
      }
    } catch (error) {
      setStatus(error.message || "Upload failed.", "error");
      if (window.turnstile && turnstileId !== null) {
        window.turnstile.reset(turnstileId);
      }
    }
  }

  uploadForm.addEventListener("submit", submitUpload);
  typeInput.addEventListener("change", updateFileConstraints);
  updateFileConstraints();

  window.addEventListener("load", () => {
    renderTurnstile();
  });

  authApi
    .requireCatalogSession({ redirectOnFail: false })
    .then((session) => {
      sessionToken = String(session.token || "");
      authStatusEl.textContent = `Logged in as ${String(session.username || "user")}`;
      renderTurnstile();
    })
    .catch((error) => {
      setStatus(error.message || "Login required.", "error");
      authStatusEl.innerHTML = "";
      const link = document.createElement("a");
      link.href = authApi.buildAccessUrl(window.location.href);
      link.textContent = "Login on gurp.cc to upload";
      link.className = "upload-pill";
      authStatusEl.appendChild(link);
    });
})();
