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

export const GET: APIRoute = ({ site }) => {
  const urls = paths.map((p) => `  <url><loc>${new URL(p, site)}</loc></url>`).join("\n");
  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`,
    { headers: { "Content-Type": "application/xml" } },
  );
};
