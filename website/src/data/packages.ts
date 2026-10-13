// Packages on the Services and pricing page, in growth-path order.
//
// fromPrice: the starting price in rand, shown as "from R…". Leave null until
// the price is decided; the page then shows "Price on request".
// Prices exclude VAT until IsangoTech is a registered VAT vendor (see site.ts).
export interface Package {
  name: string;
  stage: 1 | 2 | 3 | 4 | null;
  /** For packages outside the stage ladder: the small label above the name. */
  label?: string;
  summary: string;
  includes: string[];
  /** Starting setup price in rand, or null for "Price on request" (or priceNote). */
  setupFrom: number | null;
  /** Starting monthly fee in rand, added to the setup price. */
  monthlyFrom?: number;
  /** setupFrom is a monthly price (the care plan). */
  monthlyOnly?: boolean;
  /** The price is fixed, not a starting price. */
  fixed?: boolean;
  /** Shown instead of a price when setupFrom is null. */
  priceNote?: string;
  /** A short line under the price, e.g. a credit. */
  priceDetail?: string;
  nextStep?: string;
}

// Prices from the business plan (October 2026). Working prices to test with the
// first clients; the final price is always confirmed in a written quote.
export const packages: Package[] = [
  {
    name: "Starter website",
    stage: 1,
    summary: "A fast, mobile-friendly website that makes you easy to find and easy to trust.",
    includes: [
      "Up to five pages, written in plain language",
      "Google Business Profile set up or tidied up",
      "WhatsApp button on every page",
      "Domain and hosting set up in your name, with a short guide",
    ],
    setupFrom: null,
    priceNote: "Quoted after a free chat",
    priceDetail: "Yours to keep. No monthly fee",
    nextStep: "When enquiries start coming in, Core Starter answers every one of them.",
  },
  {
    name: "Core Starter",
    stage: 2,
    summary: "A WhatsApp assistant that answers your customers the moment they message, day or night.",
    includes: [
      "WhatsApp AI assistant for prices, hours and common questions",
      "Every enquiry captured in one list",
      "Automatic reminders so customers turn up",
      "Live in 2 to 3 weeks, with training",
      "Monthly fee covers hosting, AI usage, updates and support",
    ],
    setupFrom: 4500,
    monthlyFrom: 650,
    nextStep: "Ready for bookings and orders in one place? Move up to Core Business.",
  },
  {
    name: "Core Business",
    stage: 3,
    summary: "Bookings, orders and an owner dashboard, set up for how your industry works.",
    includes: [
      "Everything in Core Starter",
      "Bookings or orders taken on WhatsApp and online",
      "Owner dashboard: bookings, sales, busy times and regulars",
      "Deposit and balance reminders",
      "Training for you and your team",
    ],
    setupFrom: 8500,
    monthlyFrom: 1200,
    nextStep: "Once it all runs in one system, automation takes the repetitive jobs.",
  },
  {
    name: "AI Readiness Assessment",
    stage: 4,
    summary: "For businesses already running on a website or system. We find what's worth automating, and what isn't.",
    includes: [
      "On-site or online visit to map how you work",
      "Written findings in plain language",
      "A costed plan for what to automate first",
    ],
    setupFrom: 1500,
    fixed: true,
    priceDetail: "Credited against your project if you go ahead",
    nextStep: "Then we build the automation that pays for itself first.",
  },
  {
    name: "Automation add-ons",
    stage: null,
    label: "After your assessment",
    summary: "AI that handles the admin that eats your week, linked to the tools you already use.",
    includes: [
      "Quotes drafted from enquiries",
      "Invoices and payment reminders",
      "Documents read, sorted and filed",
      "Monthly care included in your plan",
    ],
    setupFrom: 3500,
    priceDetail: "Per automation",
  },
  {
    name: "Custom software",
    stage: null,
    label: "When you need more",
    summary: "When you need more than the core platform: web and mobile apps, staff portals and dashboards, built AI-ready.",
    includes: [
      "Scoped and priced in writing before we start",
      "Yours to own, handed over with documentation",
      "Look after it yourself, or add our optional care plan",
    ],
    setupFrom: 15000,
  },
  {
    name: "Care plan",
    stage: null,
    label: "Optional, for custom software",
    summary: "Rather not look after it yourself? We'll keep your custom software running and improving. Cancel any time.",
    includes: [
      "Hosting, backups and security updates",
      "Small improvements each month",
      "Help on WhatsApp when something goes wrong",
      "A short results review",
    ],
    setupFrom: 1500,
    monthlyOnly: true,
    priceDetail: "WhatsApp assistant and portal plans already include care in their monthly fee",
  },
];

// isiXhosa, by the English package name. Reviewed by the founder before it goes
// live; product names and tech words stay in English.
type PackageWords = Pick<Package, "name" | "summary" | "includes"> &
  Partial<Pick<Package, "label" | "priceNote" | "priceDetail" | "nextStep">>;
const packagesXh: Record<string, PackageWords> = {
  "Starter website": {
    name: "I-website yokuqalisa",
    summary: "I-website ekhawulezayo, esebenza kakuhle kwifowuni, ekwenza ufumaneke lula kwaye uthembeke.",
    includes: [
      "Ukuya kumaphepha amahlanu, abhalwe ngolwimi olucacileyo",
      "I-Google Business Profile isetwe okanye ilungiswe",
      "Iqhosha le-WhatsApp kulo lonke iphepha",
      "I-domain ne-hosting zisetwe egameni lakho, nesikhokelo esifutshane",
    ],
    priceNote: "Ixabiso emva kwencoko yasimahla",
    priceDetail: "Yeyakho ngokupheleleyo. Akukho ntlawulo yenyanga",
    nextStep: "Xa imibuzo iqala ukungena, i-Core Starter iyiphendula yonke.",
  },
  "Core Starter": {
    name: "Core Starter",
    summary: "I-WhatsApp assistant ephendula abathengi bakho kwangoko xa bethumela umyalezo, emini nasebusuku.",
    includes: [
      "I-WhatsApp AI assistant yamaxabiso, iiyure nemibuzo eqhelekileyo",
      "Wonke umbuzo ubhalwa kuluhlu olunye",
      "Izikhumbuzo ezizenzekelayo ukuze abathengi bafike",
      "Iqala ukusebenza kwiiveki ezi-2 ukuya kwezi-3, kunye noqeqesho",
      "Intlawulo yenyanga ihlawulela i-hosting, ukusetyenziswa kwe-AI, uhlaziyo nenkxaso",
    ],
    nextStep: "Ukulungele ii-booking nee-oda kwindawo enye? Nyukela kwi-Core Business.",
  },
  "Core Business": {
    name: "Core Business",
    summary: "Ii-booking, ii-oda ne-dashboard yomnini, kusetwe ngendlela ishishini lakho elisebenza ngayo.",
    includes: [
      "Yonke into ekwi-Core Starter",
      "Ii-booking okanye ii-oda zithathwa kwi-WhatsApp nakwi-intanethi",
      "I-dashboard yomnini: ii-booking, intengiso, amaxesha axakekileyo nabathengi abaqhelekileyo",
      "Izikhumbuzo zedipozithi nentsalela",
      "Uqeqesho lwakho neqela lakho",
    ],
    nextStep: "Xa yonke into isebenza kwinkqubo enye, i-automation ithatha imisebenzi ephindaphindwayo.",
  },
  "AI Readiness Assessment": {
    name: "AI Readiness Assessment",
    summary: "Yamashishini asele esebenzisa i-website okanye inkqubo. Sifumanisa into efanele ukwenziwa ngokuzenzekelayo, nengafanelanga.",
    includes: [
      "Utyelelo apho ukhoyo okanye kwi-intanethi lokubona indlela osebenza ngayo",
      "Iziphumo ezibhaliweyo ngolwimi olucacileyo",
      "Isicwangciso esinamaxabiso sento ekufuneka yenziwe ngokuzenzekelayo kuqala",
    ],
    priceDetail: "Ibalelwa kwiprojekthi yakho ukuba uyaqhubeka",
    nextStep: "Emva koko sakha i-automation ezihlawulela yona kuqala.",
  },
  "Automation add-ons": {
    name: "Ii-automation add-ons",
    label: "Emva kovavanyo lwakho",
    summary: "I-AI esebenza i-admin etya iveki yakho, idityaniswe nezixhobo osele uzisebenzisa.",
    includes: [
      "Iikowuti ezibhalwa zisuka kwimibuzo",
      "Ii-invoyisi nezikhumbuzo zentlawulo",
      "Amaxwebhu afundwa, ahlelwe kwaye agcinwe",
      "Ukhathalelo lwenyanga lubandakanyiwe kwisicwangciso sakho",
    ],
    priceDetail: "Nge-automation nganye",
  },
  "Custom software": {
    name: "I-software eyenzelwe wena",
    label: "Xa ufuna ngaphezulu",
    summary: "Xa ufuna ngaphezu kweqonga eliphambili: ii-app ze-web nezeefowuni, ii-portal zabasebenzi nee-dashboard, ezakhelwe i-AI.",
    includes: [
      "Umsebenzi nexabiso zibhalwa phantsi ngaphambi kokuba siqale",
      "Yeyakho, inikezelwa namaxwebhu",
      "Yikhathalele ngokwakho, okanye wongeze i-care plan yethu ekhethwayo",
    ],
  },
  "Care plan": {
    name: "I-care plan",
    label: "Ikhethwa, ye-software eyenzelwe wena",
    summary: "Awufuni ukuyikhathalela ngokwakho? Siza kugcina i-software yakho isebenza kwaye iphucuka. Rhoxisa nanini na.",
    includes: [
      "I-hosting, ii-backup nohlaziyo lokhuseleko",
      "Uphuculo oluncinci inyanga nganye",
      "Uncedo kwi-WhatsApp xa kukho into engahambanga kakuhle",
      "Uphononongo olufutshane lweziphumo",
    ],
    priceDetail: "Izicwangciso ze-WhatsApp assistant ne-portal sele zibandakanya ukhathalelo kwintlawulo yenyanga",
  },
};

/** The packages in the page's language. */
export function packagesFor(lang: "en" | "xh"): Package[] {
  return lang === "en" ? packages : packages.map((p) => ({ ...p, ...packagesXh[p.name] }));
}

const rand = (n: number) => `R${n.toLocaleString("en-ZA").replace(/,/g, "\u00a0")}`;

export function formatPrice(p: Package, lang: "en" | "xh" = "en"): string {
  if (lang === "xh") {
    if (p.setupFrom === null) return p.priceNote ?? "Ixabiso ngesicelo";
    if (p.monthlyOnly) return `ukusuka ku-${rand(p.setupFrom)} ngenyanga`;
    const setup = p.fixed ? rand(p.setupFrom) : `ukusuka ku-${rand(p.setupFrom)}`;
    return p.monthlyFrom ? `${setup} + ${rand(p.monthlyFrom)} ngenyanga` : setup;
  }
  if (p.setupFrom === null) return p.priceNote ?? "Price on request";
  if (p.monthlyOnly) return `from ${rand(p.setupFrom)} a month`;
  const setup = p.fixed ? rand(p.setupFrom) : `from ${rand(p.setupFrom)}`;
  return p.monthlyFrom ? `${setup} setup + ${rand(p.monthlyFrom)} a month` : setup;
}
