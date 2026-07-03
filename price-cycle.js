(() => {
  const slot = document.querySelector("[data-price-slot]");
  if (!slot) return;

  const BASE_GBP = 5;
  const CURRENCIES = [
    { symbol: "£", rate: 1, decimals: 0 },
    { symbol: "$", rate: 1.27, decimals: 2 },
    { symbol: "€", rate: 1.17, decimals: 2 },
    { symbol: "CA$", rate: 1.71, decimals: 2 },
    { symbol: "A$", rate: 1.93, decimals: 2 },
    { symbol: "¥", rate: 159, decimals: 0 },
  ];

  const INTERVAL_MS = 5000;
  const SPIN_MS = 900;
  const REPEAT = 8;

  const track = slot.querySelector(".price-slot-track");
  const windowEl = slot.querySelector(".price-slot-window");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function formatPrice(currency) {
    const amount = BASE_GBP * currency.rate;
    const formatted = amount.toLocaleString("en-GB", {
      minimumFractionDigits: currency.decimals,
      maximumFractionDigits: currency.decimals,
    });
    return `${currency.symbol}${formatted}`;
  }

  const cycle = CURRENCIES.map(formatPrice);
  const items = [];
  for (let i = 0; i < REPEAT; i += 1) {
    items.push(...cycle);
  }

  track.innerHTML = items
    .map((price) => `<span class="price-slot-item">${price}</span>`)
    .join("");

  let index = cycle.length * 2;
  let itemHeight = 0;
  let timerId = null;
  let logical = 0;

  function measure() {
    const first = track.querySelector(".price-slot-item");
    if (!first) return;
    itemHeight = first.getBoundingClientRect().height;
    windowEl.style.height = `${itemHeight}px`;
    setPosition(index, false);
  }

  function setPosition(nextIndex, animate) {
    track.style.transition =
      animate && !reducedMotion
        ? `transform ${SPIN_MS}ms cubic-bezier(0.12, 0.85, 0.22, 1)`
        : "none";
    track.style.transform = `translateY(-${nextIndex * itemHeight}px)`;
    slot.classList.toggle("is-spinning", animate && !reducedMotion);
  }

  function updateLabel(price) {
    slot.setAttribute("aria-label", `Price: ${price}`);
  }

  function resetIfNeeded(position) {
    const safeStart = cycle.length * 2;
    const safeEnd = cycle.length * (REPEAT - 2);
    logical = ((position % cycle.length) + cycle.length) % cycle.length;
    if (position >= safeEnd) {
      index = safeStart + logical;
      setPosition(index, false);
    } else {
      index = position;
    }
    updateLabel(cycle[logical]);
  }

  function advance() {
    if (!itemHeight) return;

    if (reducedMotion) {
      logical = (logical + 1) % cycle.length;
      index = cycle.length * 2 + logical;
      setPosition(index, false);
      updateLabel(cycle[logical]);
      return;
    }

    const extraSpins = 2 + Math.floor(Math.random() * 2);
    const targetIndex = index + 1 + extraSpins;
    const duration = SPIN_MS + extraSpins * 110;

    track.style.transition = `transform ${duration}ms cubic-bezier(0.08, 0.82, 0.17, 1)`;
    track.style.transform = `translateY(-${targetIndex * itemHeight}px)`;
    slot.classList.add("is-spinning");

    track.addEventListener(
      "transitionend",
      () => {
        slot.classList.remove("is-spinning");
        resetIfNeeded(targetIndex);
      },
      { once: true }
    );
  }

  measure();
  updateLabel(cycle[logical]);
  window.addEventListener("resize", measure);
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
