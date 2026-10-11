// The list of pages for search engines. Add new pages here.
import type { APIRoute } from "astro";
import { allSolutions } from "../data/industries";

const paths = [
  "/",
  "/solutions/",
  ...allSolutions.map((i) => `/solutions/${i.slug}/`),
  "/services/",
  "/about/",
  "/get-started/",
  "/contact/",
  "/privacy/",
  "/terms/",
];

// Every page in both languages, each linked to its counterpart.
export const GET: APIRoute = ({ site }) => {
  const xhPath = (p: string) => (p === "/" ? "/xh/" : `/xh${p}`);
  const alts = (p: string) =>
    `<xhtml:link rel="alternate" hreflang="en-ZA" href="${new URL(p, site)}"/><xhtml:link rel="alternate" hreflang="xh-ZA" href="${new URL(xhPath(p), site)}"/>`;
  const urls = paths
    .flatMap((p) => [p, xhPath(p)].map((u) => `  <url><loc>${new URL(u, site)}</loc>${alts(p)}</url>`))
    .join("\n");
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${urls}\n</urlset>\n`,
    { headers: { "Content-Type": "application/xml" } },
  );
};
