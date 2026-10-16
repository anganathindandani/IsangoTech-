// Renders the social profile picture and cover images in this folder.
// Run from the repo root after `npm ci` in website/ (for the fonts):
//   node brand/social/render.mjs
// Needs Playwright with Chromium.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "../..");
const font = (pkg, file) => readFileSync(join(root, "website/node_modules/@fontsource", pkg, "files", file)).toString("base64");
const logo = readFileSync(join(root, "brand/logo/isangotech-logo-reversed.svg"), "utf8");
const mark = readFileSync(join(root, "brand/logo/isangotech-mark-reversed.svg"), "utf8");
const bead = Buffer.from(readFileSync(join(root, "website/public/brand/beadwork.svg"))).toString("base64");

const css = `
@font-face { font-family: Outfit; font-weight: 700; src: url(data:font/woff2;base64,${font("outfit", "outfit-latin-700-normal.woff2")}); }
@font-face { font-family: "DM Sans"; font-weight: 500; src: url(data:font/woff2;base64,${font("dm-sans", "dm-sans-latin-500-normal.woff2")}); }
* { margin: 0; box-sizing: border-box; }
html, body { width: 100%; height: 100%; }
body { background: #1b2a4a; color: #f5ebdd; font-family: "DM Sans", sans-serif; overflow: hidden; position: relative; }
svg { display: block; }
.bead { position: absolute; left: 0; right: 0; bottom: 0; background: url(data:image/svg+xml;base64,${bead}) repeat-x left bottom / var(--b) var(--b); height: var(--b); }
.ghost { position: absolute; opacity: 0.14; }
.tagline { font-family: Outfit; font-weight: 700; color: #e07a1f; line-height: 1.1; }
.line { color: rgb(245 235 221 / 0.8); }
.dot { color: #2ba8a0; padding: 0 0.4em; }
`;

// Cover: logo, tagline, what we do. `safe` keeps text clear of the profile
// picture that each platform lays over the cover.
const cover = ({ w, h, b, logoW, tag, line, align, padL, padR, ghostW, ghostRight, ghostTop }) => `
<svg class="ghost" viewBox="0 0 560 900" style="width:${ghostW}px; right:${ghostRight}px; top:${ghostTop}px"><rect x="20" y="20" width="520" height="860" rx="56" fill="none" stroke="#2ba8a0" stroke-width="40"/><path d="M104 104H456V860" fill="none" stroke="#e07a1f" stroke-width="40"/></svg>
<div style="position:absolute; inset:0 0 ${b}px 0; display:flex; flex-direction:column; justify-content:center; align-items:${align}; text-align:${align === "center" ? "center" : "left"}; padding:0 ${padR}px 0 ${padL}px; gap:${h * 0.035}px">
  <div style="width:${logoW}px">${logo}</div>
  <p class="tagline" style="font-size:${tag}px">Your gateway to smarter business</p>
  <p class="line" style="font-size:${line}px">Websites<span class="dot">·</span>WhatsApp assistants<span class="dot">·</span>Automation</p>
  <p class="line" style="font-size:${line * 0.85}px">East London, Eastern Cape<span class="dot">·</span>isangotech.co.za</p>
</div>
<div class="bead" style="--b:${b}px"></div>`;

const images = [
  {
    // Profile picture for WhatsApp, Facebook, Instagram and LinkedIn. Platforms
    // crop it to a circle, so the door sits well inside it.
    file: "isangotech-avatar.png", w: 1080, h: 1080, scale: 1,
    html: `<div style="position:absolute; inset:0; display:grid; place-items:center"><div style="width:330px; transform:translateX(8px)">${mark}</div></div>`,
  },
  {
    // Facebook page cover. Phones crop the sides, so everything stays central.
    file: "isangotech-facebook-cover.png", w: 1640, h: 624, scale: 1,
    html: cover({ w: 1640, h: 624, b: 48, logoW: 520, tag: 58, line: 30, align: "center", padL: 0, padR: 0, ghostW: 360, ghostRight: -90, ghostTop: -120 }),
  },
  {
    // LinkedIn company page cover. The logo sits over the bottom left.
    file: "isangotech-linkedin-cover.png", w: 1128, h: 191, scale: 2,
    html: cover({ w: 1128, h: 191, b: 16, logoW: 190, tag: 22, line: 13, align: "flex-start", padL: 330, padR: 0, ghostW: 150, ghostRight: -30, ghostTop: -90 }),
  },
  {
    // LinkedIn personal profile banner, for the founder. The photo covers the left.
    file: "isangotech-linkedin-profile-banner.png", w: 1584, h: 396, scale: 1,
    html: cover({ w: 1584, h: 396, b: 32, logoW: 330, tag: 40, line: 22, align: "flex-start", padL: 560, padR: 0, ghostW: 260, ghostRight: -50, ghostTop: -150 }),
  },
];

const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
for (const img of images) {
  const page = await browser.newPage({ viewport: { width: img.w, height: img.h }, deviceScaleFactor: img.scale });
  await page.setContent(`<!doctype html><html><head><style>${css}</style></head><body>${img.html}</body></html>`);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: join(here, img.file) });
  await page.close();
  console.log(img.file);
}
await browser.close();
