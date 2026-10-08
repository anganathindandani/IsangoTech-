// Packages on the Services and pricing page, in growth-path order.
//
// fromPrice: the starting price in rand, shown as "from R…". Leave null until
// the price is decided; the page then shows "Price on request".
// Prices exclude VAT until IsangoTech is a registered VAT vendor (see site.ts).
export interface Package {
  name: string;
  stage: 1 | 2 | 3 | 4 | null;
  summary: string;
  includes: string[];
  fromPrice: number | null;
  billing: "once_off" | "monthly";
  nextStep?: string;
}

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
    fromPrice: null,
    billing: "once_off",
    nextStep: "When enquiries start coming in, Core Starter makes sure none get lost.",
  },
  {
    name: "Core Starter",
    stage: 2,
    summary: "Never miss an enquiry or a booking again.",
    includes: [
      "Online booking or enquiry forms",
      "Every enquiry tracked in one list",
      "WhatsApp follow-ups and reminders",
      "Simple weekly report of new enquiries",
    ],
    fromPrice: null,
    billing: "once_off",
    nextStep: "When the admin starts piling up, Core Business brings daily work into one system.",
  },
  {
    name: "Core Business",
    stage: 3,
    summary: "One portal for your daily operations, built around how your business works.",
    includes: [
      "Staff or operations portal",
      "Modules for events, staff, menus, stock or invoices",
      "Add-ons as you grow",
      "Training for you and your team",
    ],
    fromPrice: null,
    billing: "once_off",
    nextStep: "Once your data lives in one place, automation can take the repetitive work off your plate.",
  },
  {
    name: "AI Readiness Assessment",
    stage: 4,
    summary: "We visit, look at how you work, and show you what's worth automating and what isn't.",
    includes: [
      "On-site or online visit",
      "Written findings in plain language",
      "A recommended solution with a clear price",
    ],
    fromPrice: null,
    billing: "once_off",
    nextStep: "Then we build the automation that pays for itself first.",
  },
  {
    name: "Care plan",
    stage: null,
    summary: "Hosting, updates and support so everything keeps working. Available at every stage.",
    includes: [
      "Hosting, backups and security updates",
      "Small changes each month",
      "Help on WhatsApp when something goes wrong",
    ],
    fromPrice: null,
    billing: "monthly",
  },
];

export function formatPrice(p: Package): string {
  if (p.fromPrice === null) return "Price on request";
  const amount = `R${p.fromPrice.toLocaleString("en-ZA").replace(/,/g, " ")}`;
  return p.billing === "monthly" ? `from ${amount} a month` : `from ${amount}`;
}
