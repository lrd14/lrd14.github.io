(() => {
  const root = document.querySelector("[data-price-cycle]");
  if (!root) return;

  const windowEl = root.querySelector(".price-cycle-window");
  const track = root.querySelector(".price-cycle-track");
  if (!windowEl || !track) return;

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
  let stepHeight = 0;

  let itemA = track.querySelector(".price-cycle-item");
  if (!itemA) {
    itemA = document.createElement("span");
    itemA.className = "price-cycle-item";
    track.appendChild(itemA);
  }

  const itemB = document.createElement("span");
  itemB.className = "price-cycle-item";
  track.appendChild(itemB);

  const items = [itemA, itemB];

  function nextIndex(current) {
    return (current + 1) % PRICES.length;
  }

  function setLabel(price) {
    root.setAttribute("aria-label", `Price: ${price}`);
  }

  function transitionValue() {
    return reducedMotion ? "none" : `transform ${ANIM_MS}ms cubic-bezier(0.12, 0.85, 0.22, 1)`;
  }

  function applyLayout() {
    windowEl.style.display = "block";
    windowEl.style.overflow = "hidden";
    track.style.display = "block";
    items.forEach((item) => {
      item.style.display = "block";
      item.style.height = "1.1em";
      item.style.lineHeight = "1.1em";
      item.style.whiteSpace = "nowrap";
    });
    measure();
  }

  function measure() {
    stepHeight = Math.ceil(items[0].getBoundingClientRect().height);
    if (!stepHeight) {
      const fontSize = parseFloat(getComputedStyle(root.closest(".purchase-price") || root).fontSize);
      stepHeight = Math.ceil(fontSize * 1.1);
    }
    windowEl.style.height = `${stepHeight}px`;
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
    measure();
    fitWindow(false);
  }

  function finishAdvance(upcoming) {
    index = upcoming;
    track.style.transition = "none";
    track.style.transform = "translate3d(0, 0, 0)";
    syncItems();
    void track.offsetHeight;
    track.style.transition = transitionValue();
    animating = false;
  }

  function advance() {
    if (animating || !stepHeight) return;
    animating = true;

    const upcoming = nextIndex(index);
    items[1].textContent = PRICES[upcoming];
    measure();
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

    track.style.transition = "none";
    track.style.transform = "translate3d(0, 0, 0)";
    void track.offsetHeight;
    track.style.transition = transitionValue();

    requestAnimationFrame(() => {
      track.style.transform = `translate3d(0, -${stepHeight}px, 0)`;
    });

    track.addEventListener(
      "transitionend",
      (event) => {
        if (event.target !== track || event.propertyName !== "transform") return;
        complete();
      },
      { once: true }
    );

    window.setTimeout(complete, ANIM_MS + 150);
  }

  applyLayout();
  syncItems();
  track.style.transition = transitionValue();

  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(() => {
      measure();
      fitWindow(false);
    });
  }

  window.addEventListener("resize", () => {
    measure();
    fitWindow(false);
  });

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
