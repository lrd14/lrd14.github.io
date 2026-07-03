(() => {
  const root = document.querySelector("[data-price-cycle]");
  if (!root) return;

  const track = root.querySelector(".price-cycle-track");
  const items = track ? Array.from(track.querySelectorAll(".price-cycle-item")) : [];
  if (!track || items.length < 2) return;

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

  function syncItems() {
    items[0].textContent = PRICES[index];
    items[1].textContent = PRICES[nextIndex(index)];
    setLabel(PRICES[index]);
  }

  function itemHeight() {
    return items[0].getBoundingClientRect().height;
  }

  function advance() {
    if (animating) return;
    animating = true;

    const upcoming = nextIndex(index);
    items[1].textContent = PRICES[upcoming];

    if (reducedMotion) {
      index = upcoming;
      syncItems();
      animating = false;
      return;
    }

    const height = itemHeight();
    track.style.transition = `transform ${ANIM_MS}ms cubic-bezier(0.12, 0.85, 0.22, 1)`;
    track.style.transform = `translateY(-${height}px)`;

    track.addEventListener(
      "transitionend",
      () => {
        index = upcoming;
        track.style.transition = "none";
        track.style.transform = "translateY(0)";
        syncItems();
        animating = false;
      },
      { once: true }
    );
  }

  syncItems();
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
