// The growth path from the spec. Every page that talks about stages reads from here.
export interface Stage {
  number: 1 | 2 | 3 | 4;
  name: string;
  /** How a visitor would describe where they are. */
  whereYouAre: string;
  need: string;
  offer: string;
  package: string;
  nextStep: string;
}

export const stages: Stage[] = [
  {
    number: 1,
    name: "Get found",
    whereYouAre: "People can't find us online, or what they find doesn't look like us.",
    need: "Be visible and look credible",
    offer: "A website, your Google Business Profile set up properly, and a WhatsApp button so people can reach you in one tap.",
    package: "Starter website",
    nextStep: "Capture enquiries properly",
  },
  {
    number: 2,
    name: "Capture and respond",
    whereYouAre: "Enquiries come in, but some slip through the cracks.",
    need: "Stop losing enquiries",
    offer: "Booking forms, lead tracking and WhatsApp follow-ups, so every enquiry gets an answer.",
    package: "Core Starter",
    nextStep: "Run daily operations in one system",
  },
  {
    number: 3,
    name: "Run operations",
    whereYouAre: "We run the business on spreadsheets, paper and WhatsApp groups.",
    need: "Replace spreadsheets and WhatsApp threads",
    offer: "A staff or operations portal for your events, staff, menus, stock and invoices, all in one place.",
    package: "Core Business plus add-ons",
    nextStep: "Automate repetitive work",
  },
  {
    number: 4,
    name: "Automate",
    whereYouAre: "Our systems work, but the same jobs eat hours every week.",
    need: "Save time and serve more customers",
    offer: "AI and automation built on your portal's data, starting with an AI Readiness Assessment.",
    package: "AI Readiness Assessment, then custom work",
    nextStep: "Ongoing improvement",
  },
];

export const carePlan = {
  name: "Care plan",
  need: "Keep it running",
  offer: "Hosting, updates and support, at every stage.",
  nextStep: "Upgrade to the next stage when you're ready",
};

export function stageByNumber(n: number): Stage | undefined {
  return stages.find((s) => s.number === n);
}
