// The site is in English at /… and isiXhosa at /xh/…. Pages and components read
// the language from the address, so both languages share one set of templates;
// only the words differ.
export type Lang = "en" | "xh";

export const langNames: Record<Lang, string> = { en: "English", xh: "isiXhosa" };

/** The language of a page, from its address. */
export function langOf(url: URL): Lang {
  return url.pathname === "/xh" || url.pathname.startsWith("/xh/") ? "xh" : "en";
}

/** "/services" in the given language: "/services" or "/xh/services". */
export function localize(path: string, lang: Lang): string {
  if (lang === "en") return path;
  return path === "/" ? "/xh/" : `/xh${path}`;
}

/** The same page in the other language. */
export function counterpart(pathname: string, to: Lang): string {
  const base = pathname.replace(/^\/xh(?=\/|$)/, "") || "/";
  return localize(base, to);
}

/** Picks the words for this language from a { en, xh } pair. */
export function pick<T>(lang: Lang, words: { en: T; xh: T }): T {
  return words[lang];
}
