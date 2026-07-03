(() => {
  const root = document.querySelector("[data-price-cycle]");
  if (!root) return;

  const windowEl = root.querySelector(".price-cycle-window");
  const track = root.querySelector(".price-cycle-track");
  const items = track ? Array.from(track.querySelectorAll(".price-cycle-item")) : [];
  if (!windowEl || !track || items.length < 2) return;

  const BASE_GBP = 5;
  const PRICES = [
    { symbol: "£", rate: 1, decimals: 0 },
    { symbol: "$", rate: 1.27, decimals: 2 },
    { symbol: "€", rate: 1.17, decimals: 2 },
    { symbol: "CA$", rate: 1.71, decimals: 2 },
    { symbol: "A$", rate: 1.93, decimals: 2 },
    { symbol: "¥", rate: 159, decimals: 0 },
  ].map(({ symbol, rate, decimals }) => {
    const amount = BASE_GBP * rate;
    const formatted = amount.toLocaleString("en-GB", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals,
    });
    return `${symbol}${formatted}`;
  });

  const INTERVAL_MS = 5000;
  const ANIM_MS = 650;
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let index = 0;
  let timerId = null;
  let animating = false;

  function nextIndex(current) {
    return (current + 1) % PRICES.length;
  }

  function setLabel(price) {
    root.setAttribute("aria-label", `Price: ${price}`);
  }

  function itemWidth(el) {
    return Math.ceil(el.getBoundingClientRect().width);
  }

  function fitWindow(includeNext) {
    const width = includeNext
      ? Math.max(itemWidth(items[0]), itemWidth(items[1]))
      : itemWidth(items[0]);
    windowEl.style.width = `${width}px`;
  }

  function syncItems() {
    items[0].textContent = PRICES[index];
    items[1].textContent = PRICES[nextIndex(index)];
    setLabel(PRICES[index]);
    fitWindow(false);
  }

  function finishAdvance(upcoming) {
    index = upcoming;
    track.style.transition = "none";
    track.classList.remove("is-advancing");
    syncItems();
    requestAnimationFrame(() => {
      track.style.transition = "";
    });
    animating = false;
  }

  function advance() {
    if (animating) return;
    animating = true;

    const upcoming = nextIndex(index);
    items[1].textContent = PRICES[upcoming];
    fitWindow(true);

    if (reducedMotion) {
      finishAdvance(upcoming);
      return;
    }

    let finished = false;
    const complete = () => {
      if (finished) return;
      finished = true;
      finishAdvance(upcoming);
    };

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        track.classList.add("is-advancing");
      });
    });

    track.addEventListener("transitionend", (event) => {
      if (event.target !== track || event.propertyName !== "transform") return;
      complete();
    });

    window.setTimeout(complete, ANIM_MS + 120);
  }

  syncItems();
  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(() => fitWindow(false));
  }
  window.addEventListener("resize", () => fitWindow(false));
  timerId = window.setInterval(advance, INTERVAL_MS);

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      window.clearInterval(timerId);
      timerId = null;
      return;
    }
    if (!timerId) {
      timerId = window.setInterval(advance, INTERVAL_MS);
    }
  });
})();
