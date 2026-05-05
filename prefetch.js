(() => {
  const prefetched = new Set();

  function normalizeUrl(href) {
    try {
      const url = new URL(href, window.location.origin);
      if (url.origin !== window.location.origin) return null;
      if (url.pathname === window.location.pathname && !url.search) return null;
      if (url.hash && url.pathname === window.location.pathname) return null;
      if (url.pathname.startsWith("/dl")) return null;
      return url.pathname + url.search;
    } catch {
      return null;
    }
  }

  function prefetch(href) {
    const normalized = normalizeUrl(href);
    if (!normalized || prefetched.has(normalized)) return;
    prefetched.add(normalized);

    const link = document.createElement("link");
    link.rel = "prefetch";
    link.as = "document";
    link.href = normalized;
    document.head.appendChild(link);
  }

  function wireLink(link) {
    if (!link || !link.href) return;
    const trigger = () => prefetch(link.href);
    link.addEventListener("pointerenter", trigger, { passive: true });
    link.addEventListener("focus", trigger, { passive: true });
    link.addEventListener("touchstart", trigger, { passive: true });
  }

  function init() {
    const links = document.querySelectorAll("a[href]");
    links.forEach(wireLink);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
