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
  /** isiXhosa only: the whole "Let's talk about your …" heading. */
  talkAbout?: string;
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

// isiXhosa, reviewed by the founder before it goes live. Tech words stay in English.
type IndustryWords = Pick<Industry, "name" | "tagline" | "noun" | "pains" | "byStage" | "talkAbout">;
const industriesXh: Record<string, IndustryWords> = {
  salons: {
    noun: "isalon",
    name: "Iisalon nezobuhle",
    tagline: "Izitulo ezigcweleyo, abangafikiyo abambalwa.",
    talkAbout: "Masithethe ngesalon yakho",
    pains: [
      "Ii-booking zingena nge-WhatsApp, Instagram nangefowuni, kwaye ezinye ziyaphoswa.",
      "Abathengi abafiki, kwaye ixesha elalibekelwe bona liyamosheka.",
      "Uphendula imibuzo efanayo malunga namaxabiso namaxesha imini yonke.",
    ],
    byStage: {
      1: "I-website eneenkonzo zakho, amaxabiso neefoto zomsebenzi wakho, kwaye isalon yakho ibonakale kwi-Google Maps.",
      2: "I-WhatsApp assistant ephendula imibuzo yamaxabiso namaxesha akhoyo ngoko nangoko, kunye nezikhumbuzo ezinciphisa abangafikiyo.",
      3: "Ukubhukisha ixesha kumlungisi-nwele ngamnye, ukujonga ii-booking zosuku, ne-dashboard yengeniso nabathengi abaqhelekileyo.",
      4: "Izikhumbuzo zokubhukisha kwakhona ezizenzekelayo, imbali yabathengi nezicelo zezimvo ezizisebenzelayo.",
    },
  },
  restaurants: {
    noun: "irestyu",
    name: "Iirestyu namashishini okutya",
    tagline: "Iitafile ezininzi ezizeleyo, ixesha elincinci kwi-admin.",
    talkAbout: "Masithethe ngerestyu yakho",
    pains: [
      "Ii-booking zeetafile nee-oda zifika kwiindawo ezininzi kakhulu.",
      "Iimenyu namaxabiso akwi-intanethi akahlaziywanga.",
      "Isitokhwe, iishifti zabasebenzi nababoneleli zigcinwe kwiincwadana nakwii-spreadsheet.",
    ],
    byStage: {
      1: "I-website enemenyu ehlaziyiweyo, iiyure zokuvula neqhosha le-WhatsApp, kunye noluhlu olufanelekileyo kwi-Google.",
      2: "Imenyu yakho, iiyure nendlela yokufika ziphendulwa ngokuzenzekelayo kwi-WhatsApp, kwaye zonke ii-reservation zibhalwa kuluhlu olunye.",
      3: "Ii-oda nee-reservation nge-WhatsApp, neengxelo zemihla ngemihla zentengiso nesitokhwe.",
      4: "Izilumkiso zesitokhwe, ii-oda kubaboneleli ezizenzekelayo neengxelo zeveki ezizibhalayo.",
    },
  },
  caterers: {
    noun: "ishishini lokupheka",
    name: "Abapheki beminyhadala",
    tagline: "Nika iikowuti ngokukhawuleza, uphumelele iminyhadala emininzi.",
    talkAbout: "Masithethe ngeshishini lakho lokupheka",
    pains: [
      "Imibuzo yeminyhadala ifuna iikowuti ezikhawulezayo, kwaye impendulo ecothayo ilahlekisa umsebenzi.",
      "Iimenyu, inani leendwendwe neemfuno zokutya ziyatshintsha kude kube ngumhla womnyhadala.",
      "Abasebenzi, izixhobo needipozithi zilandelwa ngesandla.",
    ],
    byStage: {
      1: "I-website ebonisa iimenyu zakho neminyhadala odlulileyo, enendlela elula yokucela ikowuti.",
      2: "Imibuzo yeminyhadala iphendulwa ngoko nangoko kwi-WhatsApp, kubhalwa umhla, inani leendwendwe nemenyu, ize ilandelwe ide ibe yi-booking.",
      3: "Iikowuti ezikhawulezayo ezisuka kwiinkcukacha zomnyhadala, ucwangciso lweminyhadala nolwabasebenzi, nezikhumbuzo zedipozithi nentsalela.",
      4: "Ii-invoyisi, ii-oda kubaboneleli nezikhumbuzo zamanani okugqibela zenziwa ngokuzenzekelayo.",
    },
  },
  guesthouses: {
    noun: "indlu yeendwendwe",
    name: "Iindlu zeendwendwe nee-B&B",
    tagline: "Ii-booking ezininzi ezithe ngqo, ikomishini encinci.",
    talkAbout: "Masithethe ngendlu yakho yeendwendwe",
    pains: [
      "Ii-booking zisasazeke kwi-WhatsApp, kwiifowuni nakwiisayithi zokubhukisha.",
      "Yonke i-booking ye-intanethi ikuhlawulisa ikomishini.",
      "Iinkcukacha zokungena, iidipozithi nezimvo zilandelwa ngesandla.",
    ],
    byStage: {
      1: "I-website enamagumbi akho, amaxabiso neefoto, uluhlu olufanelekileyo kwi-Google, neqhosha le-WhatsApp lee-booking ezithe ngqo.",
      2: "Ii-booking ezithe ngqo nge-WhatsApp, imibuzo ngamagumbi akhoyo iphendulwa ngoko nangoko, kwaye izicelo zedipozithi zithunyelwa endaweni yakho.",
      3: "Ikhalenda enye yee-booking, iinkcukacha zokungena zithunyelwa ngokuzenzekelayo, nezicelo zezimvo emva kokuphuma.",
      4: "Ukulandelela okubuyisa iindwendwe zangaphambili, neengxelo zamagumbi asetyenzisiweyo nengeniso.",
    },
  },
  "other-small-businesses": {
    noun: "ishishini",
    name: "Amanye amashishini amancinci",
    tagline: "Indlela efanayo yokukhula, yalo naliphi na ishishini elincinci.",
    talkAbout: "Masithethe ngeshishini lakho",
    pains: [
      "Kunzima ukukufumana kwi-intanethi, okanye oko abantu bakufumanayo akufani nawe.",
      "Imibuzo ingena nge-WhatsApp, ifowuni ne-imeyile, kwaye eminye iyalahleka.",
      "I-admin yemihla ngemihla igcinwe kwii-spreadsheet nakwimicu yeengxoxo.",
    ],
    byStage: {
      1: "I-website, i-Google Business Profile neqhosha le-WhatsApp ezikwenza ufumaneke lula kwaye uthembeke.",
      2: "I-WhatsApp assistant nokulandelela okubamba wonke umbuzo.",
      3: "Ii-booking okanye ii-oda kwinkqubo enye, ne-dashboard yomnini, ilungiselelwe ishishini lakho.",
      4: "I-automation yemisebenzi etya iveki yakho.",
    },
  },
};

/** An industry in the page's language. */
export function industryFor(i: Industry, lang: "en" | "xh"): Industry {
  return lang === "en" ? i : { ...i, ...industriesXh[i.slug] };
}

/** All solutions in the page's language. */
export function solutionsFor(lang: "en" | "xh"): Industry[] {
  return allSolutions.map((i) => industryFor(i, lang));
}
