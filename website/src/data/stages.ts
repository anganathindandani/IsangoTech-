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
    offer: "A WhatsApp assistant that answers every enquiry the moment it arrives, with reminders so customers turn up.",
    package: "Core Starter",
    nextStep: "Run daily operations in one system",
  },
  {
    number: 3,
    name: "Run operations",
    whereYouAre: "We run the business on spreadsheets, paper and WhatsApp groups.",
    need: "Replace spreadsheets and WhatsApp threads",
    offer: "Bookings and orders in one system, with a dashboard that shows your sales, busy times and regulars.",
    package: "Core Business",
    nextStep: "Automate repetitive work",
  },
  {
    number: 4,
    name: "Automate",
    whereYouAre: "Our systems work, but the same jobs eat hours every week.",
    need: "Save time and serve more customers",
    offer: "An AI Readiness Assessment to find what's worth automating, then automation that takes the repetitive work off your plate.",
    package: "AI Readiness Assessment, then automation add-ons",
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
