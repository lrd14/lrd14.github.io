(() => {
  const searchInput = document.getElementById("docSearch");
  const emptyState = document.getElementById("searchEmpty");
  const sections = Array.from(document.querySelectorAll("[data-doc-section]"));
  const tocLinks = Array.from(document.querySelectorAll("[data-toc-link]"));
  const groups = Array.from(document.querySelectorAll("[data-toc-group]"));
  const toggles = Array.from(document.querySelectorAll("[data-group-toggle]"));
  const titleById = new Map(
    tocLinks.map((link) => {
      const id = (link.getAttribute("href") || "").replace(/^#/, "");
      const titleNode = link.querySelector("span");
      const title = titleNode ? titleNode.textContent.trim() : link.textContent.trim();
      return [id, title || id];
    })
  );

  if (!sections.length) return;

  function sectionIdFromHash() {
    const raw = window.location.hash.replace(/^#/, "").trim();
    return raw || sections[0].id;
  }

  function setActiveToc(id, visibleIds) {
    tocLinks.forEach((link) => {
      const target = (link.getAttribute("href") || "").replace(/^#/, "");
      const active = target === id;
      link.classList.toggle("active", active);
      if (visibleIds) {
        link.hidden = !visibleIds.has(target);
      } else {
        link.hidden = false;
      }
    });
  }

  function setActiveSection(id) {
    sections.forEach((section) => {
      const active = section.id === id;
      section.classList.toggle("active", active);
    });
  }

  function getVisibleSectionIds(query) {
    const term = String(query || "").trim().toLowerCase();
    const visibleIds = new Set();

    sections.forEach((section) => {
      const source = [
        section.getAttribute("data-title") || "",
        section.textContent || ""
      ]
        .join(" ")
        .toLowerCase();

      if (!term || source.includes(term)) {
        visibleIds.add(section.id);
      }
    });

    return visibleIds;
  }

  function updateGroupVisibility() {
    groups.forEach((group) => {
      const hasVisibleLink = Array.from(group.querySelectorAll("[data-toc-link]")).some((link) => !link.hidden);
      group.hidden = !hasVisibleLink;
    });
  }

  function ensurePageNav(section) {
    let nav = section.querySelector("[data-page-nav]");
    if (nav) return nav;

    nav = document.createElement("nav");
    nav.className = "page-nav";
    nav.setAttribute("data-page-nav", "true");

    const prev = document.createElement("a");
    prev.className = "page-nav-link prev";
    prev.setAttribute("data-page-nav-prev", "true");
    prev.href = "#";
    prev.textContent = "Back";

    const next = document.createElement("a");
    next.className = "page-nav-link next";
    next.setAttribute("data-page-nav-next", "true");
    next.href = "#";
    next.textContent = "Next";

    nav.appendChild(prev);
    nav.appendChild(next);
    section.appendChild(nav);
    return nav;
  }

  function updatePageNav(orderedIds) {
    sections.forEach((section) => {
      const nav = ensurePageNav(section);
      const prev = nav.querySelector("[data-page-nav-prev]");
      const next = nav.querySelector("[data-page-nav-next]");
      const index = orderedIds.indexOf(section.id);

      if (index === -1) {
        nav.hidden = true;
        return;
      }

      nav.hidden = false;

      const prevId = index > 0 ? orderedIds[index - 1] : "";
      const nextId = index < orderedIds.length - 1 ? orderedIds[index + 1] : "";

      if (prevId) {
        prev.href = `#${prevId}`;
        prev.textContent = `← Back: ${titleById.get(prevId) || prevId}`;
        prev.classList.remove("disabled");
      } else {
        prev.href = "#";
        prev.textContent = "← Back";
        prev.classList.add("disabled");
      }

      if (nextId) {
        next.href = `#${nextId}`;
        next.textContent = `Next: ${titleById.get(nextId) || nextId} →`;
        next.classList.remove("disabled");
      } else {
        next.href = "#";
        next.textContent = "Next →";
        next.classList.add("disabled");
      }
    });
  }

  function applyFilterAndRoute() {
    const visibleIds = getVisibleSectionIds(searchInput ? searchInput.value : "");
    const hasResults = visibleIds.size > 0;
    const orderedIds = tocLinks
      .map((link) => (link.getAttribute("href") || "").replace(/^#/, ""))
      .filter((id) => visibleIds.has(id));
    const currentId = sectionIdFromHash();
    const fallbackId = hasResults ? orderedIds[0] : "";
    const nextId = hasResults && visibleIds.has(currentId) ? currentId : fallbackId;

    sections.forEach((section) => {
      section.hidden = !visibleIds.has(section.id);
    });

    if (emptyState) {
      emptyState.hidden = hasResults;
    }

    if (!hasResults) {
      setActiveToc("", visibleIds);
      updateGroupVisibility();
      updatePageNav([]);
      return;
    }

    if (window.location.hash !== `#${nextId}`) {
      history.replaceState(null, "", `#${nextId}`);
    }

    setActiveSection(nextId);
    setActiveToc(nextId, visibleIds);
    updateGroupVisibility();
    updatePageNav(orderedIds);
  }

  if (searchInput) {
    searchInput.addEventListener("input", applyFilterAndRoute);
  }

  toggles.forEach((button) => {
    button.addEventListener("click", () => {
      const group = button.closest("[data-toc-group]");
      if (!group) return;
      group.classList.toggle("open");
    });
  });

  window.addEventListener("hashchange", applyFilterAndRoute);
  applyFilterAndRoute();
})();
