// What IsangoTech sells today, on the Services and pricing page.
// Prices exclude VAT until IsangoTech is a registered VAT vendor (see site.ts).
// Working prices to test with the first clients; the final price is always
// confirmed in a written quote.
export interface Package {
  name: string;
  /** website: the main offer. addon: a smaller job. care: help after launch. */
  group: "website" | "addon" | "care";
  /** The small label above the name. */
  label?: string;
  summary: string;
  includes: string[];
  /** Price in rand, or null for "Price on request" (or priceNote). */
  price: number | null;
  /** The price is per month. */
  monthly?: boolean;
  /** The price is fixed, not a starting price. */
  fixed?: boolean;
  /** Shown instead of a price when price is null. */
  priceNote?: string;
  /** A short line under the price. */
  priceDetail?: string;
}

export const packages: Package[] = [
  {
    name: "Starter website",
    group: "website",
    label: "Get found online",
    summary: "A fast, mobile-friendly website that makes you easy to find and easy to trust.",
    includes: [
      "Up to five pages, written in plain language",
      "Google Business Profile set up or tidied up",
      "WhatsApp button on every page",
      "Domain and hosting set up in your name, with a short guide",
    ],
    price: 3500,
    priceDetail: "Once-off. No monthly fee, and the website is yours.",
  },
  {
    name: "Google Business Profile setup",
    group: "addon",
    label: "On its own",
    summary: "Your business on Google Search and Maps, set up properly. Already included in the Starter website.",
    includes: [
      "Created or claimed, and verified",
      "Categories, hours, services and description",
      "Ten photos, and links to your website and WhatsApp",
    ],
    price: 950,
    fixed: true,
    priceDetail: "Once-off",
  },
  {
    name: "Website care",
    group: "care",
    label: "Optional",
    summary: "We keep your website up to date after launch, so you don't have to.",
    includes: [
      "Changes to your prices, hours, photos and text",
      "Checks that your site, domain and hosting keep working",
      "Help on WhatsApp when something goes wrong",
    ],
    price: null,
    priceNote: "Price on request",
    priceDetail: "Month to month. Cancel with 30 days' notice.",
  },
  {
    name: "Google Business Profile care",
    group: "care",
    label: "Optional",
    summary: "We keep your Google profile fresh, so Google and your customers see an active business.",
    includes: [
      "Four posts and new photos each month",
      "Every review answered within 2 working days",
      "Holiday hours kept up to date",
      "A short monthly report: calls, directions and website clicks",
    ],
    price: 450,
    monthly: true,
    fixed: true,
    priceDetail: "Month to month. Cancel with 30 days' notice. We never buy or write reviews.",
  },
];

// isiXhosa, by the English package name. Reviewed by the founder before it goes
// live; product names and tech words stay in English.
type PackageWords = Pick<Package, "name" | "summary" | "includes"> &
  Partial<Pick<Package, "label" | "priceNote" | "priceDetail">>;
const packagesXh: Record<string, PackageWords> = {
  "Starter website": {
    name: "I-website yokuqalisa",
    label: "Fumaneka kwi-intanethi",
    summary: "I-website ekhawulezayo, esebenza kakuhle kwifowuni, ekwenza ufumaneke lula kwaye uthembeke.",
    includes: [
      "Ukuya kumaphepha amahlanu, abhalwe ngolwimi olucacileyo",
      "I-Google Business Profile isetwe okanye ilungiswe",
      "Iqhosha le-WhatsApp kulo lonke iphepha",
      "I-domain ne-hosting zisetwe egameni lakho, nesikhokelo esifutshane",
    ],
    priceDetail: "Kanye kuphela. Akukho ntlawulo yenyanga, kwaye i-website yeyakho.",
  },
  "Google Business Profile setup": {
    name: "Ukuseta i-Google Business Profile",
    label: "Ngokwayo",
    summary: "Ishishini lakho kwi-Google Search nakwi-Maps, lisetwe kakuhle. Sele ibandakanyiwe kwi-website yokuqalisa.",
    includes: [
      "Iyenziwa okanye ibangwe, kwaye iqinisekiswe",
      "Iindidi, iiyure, iinkonzo nenkcazelo",
      "Iifoto ezilishumi, namakhonkco e-website yakho nawe-WhatsApp",
    ],
    priceDetail: "Kanye kuphela",
  },
  "Website care": {
    name: "Ukhathalelo lwe-website",
    label: "Ikhethwa",
    summary: "Siyigcina i-website yakho ihlaziyiwe emva kokuba iqalile, ukuze ungazikhathazi.",
    includes: [
      "Utshintsho lwamaxabiso, iiyure, iifoto nombhalo wakho",
      "Ukujonga ukuba isayithi, i-domain ne-hosting zisasebenza",
      "Uncedo kwi-WhatsApp xa kukho into engahambanga kakuhle",
    ],
    priceNote: "Ixabiso ngesicelo",
    priceDetail: "Ngenyanga nenyanga. Rhoxisa ngesaziso seentsuku ezingama-30.",
  },
  "Google Business Profile care": {
    name: "Ukhathalelo lwe-Google Business Profile",
    label: "Ikhethwa",
    summary: "Siyigcina iprofayile yakho ye-Google intsha, ukuze i-Google nabathengi bakho babone ishishini elisebenzayo.",
    includes: [
      "Iiposti ezine neefoto ezintsha inyanga nganye",
      "Uphononongo ngalunye luphendulwa kwiintsuku ezi-2 zomsebenzi",
      "Iiyure zeeholide zihlala zichanekile",
      "Ingxelo emfutshane yenyanga: iifowuni, abacela indlela nabacofa i-website",
    ],
    priceDetail: "Ngenyanga nenyanga. Rhoxisa ngesaziso seentsuku ezingama-30. Asizithengi kwaye asizibhali izimvo.",
  },
};

/** The packages in the page's language. */
export function packagesFor(lang: "en" | "xh"): Package[] {
  return lang === "en" ? packages : packages.map((p) => ({ ...p, ...packagesXh[p.name] }));
}

const rand = (n: number) => `R${n.toLocaleString("en-ZA").replace(/,/g, " ")}`;

export function formatPrice(p: Package, lang: "en" | "xh" = "en"): string {
  if (lang === "xh") {
    if (p.price === null) return p.priceNote ?? "Ixabiso ngesicelo";
    const amount = p.fixed ? rand(p.price) : `ukusuka ku-${rand(p.price)}`;
    return p.monthly ? `${amount} ngenyanga` : amount;
  }
  if (p.price === null) return p.priceNote ?? "Price on request";
  const amount = p.fixed ? rand(p.price) : `from ${rand(p.price)}`;
  return p.monthly ? `${amount} a month` : amount;
}
