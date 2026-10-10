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
      2: "A WhatsApp assistant that answers price and availability questions instantly, with reminders that cut no-shows.",
      3: "Slot booking per stylist, a daily booking view, and a dashboard of takings and regulars.",
      4: "Automatic rebooking reminders, client history and review requests that run themselves.",
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
      2: "Your menu, hours and directions answered automatically on WhatsApp, and every reservation captured in one list.",
      3: "WhatsApp ordering and reservations, with daily sales and stock reports.",
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
      2: "Event enquiries answered instantly on WhatsApp, capturing the date, headcount and menu, and tracked to a booking.",
      3: "Instant quotes from event details, event and staff scheduling, and deposit and balance reminders.",
      4: "Invoices, supplier orders and final-numbers reminders handled automatically.",
    },
  },
  {
    slug: "guesthouses",
    noun: "guesthouse",
    name: "Guesthouses and B&Bs",
    tagline: "More direct bookings, less commission.",
    pains: [
      "Bookings are scattered across WhatsApp, calls and booking sites.",
      "Every online booking costs you commission.",
      "Check-in details, deposits and reviews are chased by hand.",
    ],
    byStage: {
      1: "A website with your rooms, rates and photos, a proper Google listing, and a WhatsApp button for direct bookings.",
      2: "Direct WhatsApp bookings with availability answered instantly, and deposit requests sent for you.",
      3: "One booking calendar, check-in details sent automatically, and review requests after checkout.",
      4: "Follow-ups that bring past guests back, and reports on occupancy and income.",
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
    2: "A WhatsApp assistant and follow-ups that catch every enquiry.",
    3: "Bookings or orders in one system, with an owner dashboard, configured for your industry.",
    4: "Automation for the jobs that eat your week.",
  },
};

export const allSolutions = [...industries, otherBusinesses];
