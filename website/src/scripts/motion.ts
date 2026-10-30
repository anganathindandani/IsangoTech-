// Site-wide motion: scroll reveals, header shadow and the growth path line.
// Everything here is progressive: without this script the page is complete and static.

const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/** Elements that fade up as they enter the viewport, on every page. */
const REVEAL_SELECTOR = [
  "main h2",
  "[data-reveal-group] > *",
  ".outcomes > *",
  ".package",
  ".values li",
  ".path-step",
  ".tiles li",
  ".ways li",
  ".quotes figure",
  ".pains li",
  ".card",
  ".chat",
].join(",");

function setUpReveals() {
  const items = Array.from(document.querySelectorAll<HTMLElement>(REVEAL_SELECTOR)).filter(
    (el) => !el.closest("[data-no-reveal]"),
  );
  // Stagger siblings that share a parent.
  const counts = new Map<Element, number>();
  for (const el of items) {
    const parent = el.parentElement!;
    const i = counts.get(parent) ?? 0;
    counts.set(parent, i + 1);
    el.dataset.reveal = "";
    el.style.setProperty("--reveal-i", String(Math.min(i, 6)));
  }

  if (reduced || !("IntersectionObserver" in window)) {
    items.forEach((el) => el.classList.add("is-visible"));
    return;
  }

  const show = (el: Element) => {
    el.classList.add("is-visible");
    observer.unobserve(el);
  };
  // Starts a little before an item scrolls into view, so it's there by the time it's seen.
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting || entry.boundingClientRect.top < 0) show(entry.target);
      }
    },
    { rootMargin: "0px 0px 15% 0px", threshold: 0 },
  );
  items.forEach((el) => observer.observe(el));

  // A fast scroll can jump straight past an item without it ever intersecting:
  // show everything above the bottom of the screen.
  let pending = false;
  const catchUp = () => {
    pending = false;
    for (const el of items) {
      if (!el.classList.contains("is-visible") && el.getBoundingClientRect().top < window.innerHeight) show(el);
    }
  };
  window.addEventListener(
    "scroll",
    () => {
      if (!pending) {
        pending = true;
        requestAnimationFrame(catchUp);
      }
    },
    { passive: true },
  );
}

function setUpHeader() {
  const header = document.querySelector<HTMLElement>(".site-header");
  if (!header) return;
  const update = () => header.classList.toggle("is-scrolled", window.scrollY > 8);
  update();
  window.addEventListener("scroll", update, { passive: true });
}

/** The growth path's line fills as the section scrolls through the viewport. */
function setUpPaths() {
  const paths = Array.from(document.querySelectorAll<HTMLElement>("[data-path]"));
  if (paths.length === 0) return;

  const update = () => {
    const vh = window.innerHeight;
    for (const path of paths) {
      const rect = path.getBoundingClientRect();
      const raw = (vh * 0.8 - rect.top) / (rect.height * 0.9);
      const progress = reduced ? 1 : Math.max(0, Math.min(1, raw));
      path.style.setProperty("--progress", progress.toFixed(3));
      const steps = path.querySelectorAll<HTMLElement>(".path-step");
      steps.forEach((step, i) => {
        step.classList.toggle("is-active", progress >= (i + 0.35) / steps.length);
      });
    }
  };

  update();
  if (reduced) return;
  let queued = false;
  const onScroll = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      update();
    });
  };
  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll);
}

setUpReveals();
setUpHeader();
setUpPaths();
document.documentElement.dataset.motionReady = "true";
