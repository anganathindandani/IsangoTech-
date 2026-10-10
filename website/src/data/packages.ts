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
      "Hosting and your own domain name",
    ],
    setupFrom: null,
    priceNote: "Quoted after a free chat",
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
      "Hosting, updates and support included monthly",
    ],
    setupFrom: 4500,
    monthlyFrom: 650,
    nextStep: "When you're ready to take bookings and orders in one place, move up to Core Business.",
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
    nextStep: "Once your work runs through one system, automation can take the repetitive jobs off your plate.",
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
      "Built on the same tested platform",
      "Care plan for hosting, monitoring and improvements",
    ],
    setupFrom: 15000,
    monthlyFrom: 1500,
  },
  {
    name: "Care plan",
    stage: null,
    label: "Every stage",
    summary: "Hosting, monitoring, updates and support so everything keeps working. We stay after launch.",
    includes: [
      "Hosting, backups and security updates",
      "Small improvements each month",
      "Help on WhatsApp when something goes wrong",
      "A short results review",
    ],
    setupFrom: null,
    priceNote: "Included in every monthly fee",
  },
];

const rand = (n: number) => `R${n.toLocaleString("en-ZA").replace(/,/g, "\u00a0")}`;

export function formatPrice(p: Package): string {
  if (p.setupFrom === null) return p.priceNote ?? "Price on request";
  const setup = p.fixed ? rand(p.setupFrom) : `from ${rand(p.setupFrom)}`;
  return p.monthlyFrom ? `${setup} setup + ${rand(p.monthlyFrom)} a month` : setup;
}
