# IsangoTech brand

## Logo

The logo is concept 2 from Brand Board v1: **the "I" as a doorway**. The first letter is a door swinging open, with warm ochre light behind it. Everything in `logo/` is vector. The wordmark is set in Outfit (weight 650, between SemiBold and Bold) and converted to outlines, so no font needs to be installed to use it.

Open `preview.html` in a browser to see every version.

| File | Use |
| --- | --- |
| `logo/isangotech-logo.svg` | Primary. White or Warm Sand backgrounds. |
| `logo/isangotech-logo-reversed.svg` | Deep Indigo or other dark backgrounds. The door turns Beadwork Turquoise and "sango" turns Warm Sand. |
| `logo/isangotech-logo-mono-indigo.svg` | One-colour printing, stamps, embroidery on light material. |
| `logo/isangotech-logo-mono-white.svg` | One-colour on photos or dark material. |
| `logo/isangotech-mark.svg` | The door on its own, for tight spaces next to the name. |
| `logo/isangotech-mark-reversed.svg` | The door on its own, on dark backgrounds. |
| `logo/isangotech-app-icon.svg` | Favicon, app icon, WhatsApp and social profile picture. Turquoise door on Deep Indigo. |
| `logo/png/` | Transparent PNG exports for tools that don't take SVG (Word, Canva, WhatsApp). |

### Decisions

- **The door is the only logo.** It replaces concept 3, the beadwork gate, everywhere: website, portal, business cards, social posts, app icon and profile pictures. The beadwork pattern stays as a signature graphic for borders, section dividers and card backs, but is never used as a logo.
- **On dark backgrounds the door is Beadwork Turquoise** (`#2BA8A0`), so it matches "Tech", with the ochre light unchanged.

### Rules

- **Clear space:** keep empty space around the logo at least as wide as the ochre light in the door.
- **Minimum size:** 120 px wide on screen, 30 mm in print. Below that, use the app icon.
- Don't recolour, stretch, rotate or add effects. Don't retype the wordmark in another font.
- Don't put the primary (indigo) logo on dark backgrounds; use the reversed version.

## Colour

| Name | Hex | Role |
| --- | --- | --- |
| Deep Indigo | `#1B2A4A` | Primary. Door frame, "sango", text. |
| Sunset Ochre | `#E07A1F` | Accent. The light in the doorway. |
| Beadwork Turquoise | `#2BA8A0` | Secondary. "Tech" on dark backgrounds. |
| Turquoise (text) | `#1D7A74` | "Tech" and turquoise text on light backgrounds. |
| Terracotta | `#B5523B` | Support. |
| Warm Sand | `#F5EBDD` | Background. Reversed logo. |

Sand and indigo carry the layout. Ochre, turquoise and terracotta are highlights, never the whole page.

## Type

- Headings: **Outfit** (SemiBold or Bold)
- Body: **DM Sans**

Both are free Google Fonts under the SIL Open Font License.

## Social media

Ready-to-upload images in `social/`. Upload the PNG as it is; each platform crops it as described.

| File | Size | Use |
| --- | --- | --- |
| `social/isangotech-avatar.png` | 1080 × 1080 | Profile picture on WhatsApp Business, Facebook, Instagram and LinkedIn. Platforms crop it to a circle; the door stays inside it. |
| `social/isangotech-facebook-cover.png` | 1640 × 624 | Facebook page cover. Phones crop the sides, so the text sits in the middle. |
| `social/isangotech-linkedin-cover.png` | 2256 × 382 | LinkedIn company page cover (1128 × 191 at double resolution). The text starts right of where the logo sits. |
| `social/isangotech-linkedin-profile-banner.png` | 1584 × 396 | The founder's personal LinkedIn banner. The text starts right of the profile photo. |

WhatsApp Business and Instagram have no cover image; they use the profile picture only.

To change the wording or colours, edit `social/render.mjs` and run `node brand/social/render.mjs` from the repo root (needs `npm ci` in `website/` for the fonts, and Playwright).
