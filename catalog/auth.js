(() => {
  const API_BASE = "https://gurp-keyauth-gateway.lrd14.workers.dev";
  const SESSION_KEY = "gurp_access_session";
  const ACCESS_URL = "https://gurp.cc/access";

  function loadRawSession() {
    const fromLocal = localStorage.getItem(SESSION_KEY);
    if (fromLocal) {
      sessionStorage.setItem(SESSION_KEY, fromLocal);
      return fromLocal;
    }
    return sessionStorage.getItem(SESSION_KEY);
  }

  function parseSession(raw) {
    if (!raw) return null;
    try {
      const parsed = JSON.parse(raw);
      if (!parsed || !parsed.token) return null;
      return parsed;
    } catch {
      return null;
    }
  }

  function clearSession() {
    sessionStorage.removeItem(SESSION_KEY);
    localStorage.removeItem(SESSION_KEY);
  }

  async function validateToken(token) {
    const response = await fetch(API_BASE, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "validate", token })
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok || !data.success) {
      throw new Error(data.message || "Session invalid.");
    }
    return data;
  }

  function buildAccessUrl(returnTo) {
    const target = String(returnTo || window.location.href || "https://catalog.gurp.cc/");
    return `${ACCESS_URL}?next=${encodeURIComponent(target)}`;
  }

  async function requireCatalogSession(options = {}) {
    const redirectOnFail = options.redirectOnFail === true;
    const raw = loadRawSession();
    const session = parseSession(raw);
    if (!session || !session.token) {
      if (redirectOnFail) {
        window.location.href = buildAccessUrl(options.returnTo);
      }
      throw new Error("Login required.");
    }

    try {
      await validateToken(session.token);
      return session;
    } catch (error) {
      clearSession();
      if (redirectOnFail) {
        window.location.href = buildAccessUrl(options.returnTo);
      }
      throw error;
    }
  }

  window.GurpCatalogAuth = {
    apiBase: API_BASE,
    requireCatalogSession,
    clearSession,
    buildAccessUrl
  };
})();
