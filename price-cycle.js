(() => {
  const root = document.querySelector("[data-price-cycle]");
  if (!root) return;

  const valueEl = root.querySelector(".price-cycle-value");
  if (!valueEl) return;

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
  const ANIM_MS = 550;
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let index = 0;
  let timerId = null;
  let animating = false;

  function setLabel(price) {
    root.setAttribute("aria-label", `Price: ${price}`);
  }

  function advance() {
    if (animating) return;
    animating = true;

    const nextIndex = (index + 1) % PRICES.length;
    const nextPrice = PRICES[nextIndex];

    if (reducedMotion) {
      index = nextIndex;
      valueEl.textContent = nextPrice;
      setLabel(nextPrice);
      animating = false;
      return;
    }

    root.classList.remove("is-entering", "is-active");
    root.classList.add("is-exiting");

    window.setTimeout(() => {
      valueEl.textContent = nextPrice;
      root.classList.remove("is-exiting");
      root.classList.add("is-entering");

      requestAnimationFrame(() => {
        root.classList.add("is-active");
      });

      window.setTimeout(() => {
        index = nextIndex;
        root.classList.remove("is-entering", "is-active");
        setLabel(nextPrice);
        animating = false;
      }, ANIM_MS);
    }, ANIM_MS);
  }

  setLabel(PRICES[0]);
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
