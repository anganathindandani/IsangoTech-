// Solutions pages. Focus industries get their own page; everyone else uses "other".
export interface Industry {
  slug: string;
  name: string;
  /** Short line for tiles. */
  tagline: string;
  /** Singular, for "Let's talk about your …". */
  noun: string;
  pains: string[];
  /** What we offer at each growth stage, in this industry's words. */
  byStage: Record<1 | 2 | 3 | 4, string>;
  /** YouTube or video URL, once the demo is recorded. */
  demoVideo?: string;
}

export const industries: Industry[] = [
  {
    slug: "salons",
    noun: "salon",
    name: "Salons and beauty",
    tagline: "Fuller chairs, fewer no-shows.",
    pains: [
      "Bookings come in on WhatsApp, Instagram and phone, and some get missed.",
      "Clients don't show up, and the slot goes to waste.",
      "You answer the same questions about prices and times all day.",
    ],
    byStage: {
      1: "A website with your services, prices and photos of your work, and your salon showing up on Google Maps.",
      2: "Online booking with WhatsApp reminders, so clients book themselves and actually turn up.",
      3: "A portal for your stylists' schedules, client history, stock and daily takings.",
      4: "Automatic rebooking reminders and a WhatsApp assistant that answers common questions after hours.",
    },
  },
  {
    slug: "restaurants",
    noun: "restaurant",
    name: "Restaurants and food businesses",
    tagline: "More tables filled, less time on admin.",
    pains: [
      "Table bookings and orders arrive in too many places.",
      "Menus and prices online are out of date.",
      "Stock, staff shifts and suppliers live in notebooks and spreadsheets.",
    ],
    byStage: {
      1: "A website with an up-to-date menu, opening hours and a WhatsApp button, plus a proper Google listing.",
      2: "Table bookings and order enquiries in one list, with automatic confirmations.",
      3: "A portal for menus, stock, staff shifts and supplier invoices.",
      4: "Stock alerts, automatic supplier orders and weekly reports that write themselves.",
    },
  },
  {
    slug: "caterers",
    noun: "catering business",
    name: "Caterers",
    tagline: "Quote faster, win more events.",
    pains: [
      "Event enquiries need quick quotes, and slow replies lose the job.",
      "Menus, headcounts and dietary needs change right up to the day.",
      "Staff, equipment and deposits are tracked by hand.",
    ],
    byStage: {
      1: "A website that shows your menus and past events, with an easy way to ask for a quote.",
      2: "An event enquiry form that captures date, headcount and menu, and tracks every lead to a booking.",
      3: "A portal for events, menus, staff, equipment, deposits and invoices.",
      4: "Quotes drafted automatically from the enquiry, and reminders for final numbers and payments.",
    },
  },
];

export const otherBusinesses: Industry = {
  slug: "other-small-businesses",
    noun: "business",
  name: "Other small businesses",
  tagline: "The same growth path, for any small business.",
  pains: [
    "You're hard to find online, or what people find doesn't look like you.",
    "Enquiries come in on WhatsApp, phone and email, and some get lost.",
    "Daily admin lives in spreadsheets and chat threads.",
  ],
  byStage: {
    1: "A website, Google Business Profile and WhatsApp button that make you easy to find and trust.",
    2: "Forms and follow-ups that catch every enquiry.",
    3: "A portal for your daily operations, built from our tested templates.",
    4: "Automation for the jobs that eat your week.",
  },
};

export const allSolutions = [...industries, otherBusinesses];
