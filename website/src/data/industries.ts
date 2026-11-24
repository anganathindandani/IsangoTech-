// Solutions pages: what a website does for each kind of business we focus on.
// Everyone else uses "other".
export interface Industry {
  slug: string;
  name: string;
  /** Short line for tiles. */
  tagline: string;
  /** Singular, for "Let's talk about your …". */
  noun: string;
  pains: string[];
  /** What their website and Google profile do for them, in their words. */
  website: string[];
  /** isiXhosa only: the whole "Let's talk about your …" heading. */
  talkAbout?: string;
}

export const industries: Industry[] = [
  {
    slug: "salons",
    noun: "salon",
    name: "Salons and beauty",
    tagline: "Easy to find, easy to book.",
    pains: [
      "People search for a salon nearby, and yours doesn't come up.",
      "Your prices and work live in old Instagram posts.",
      "New clients can't tell how to reach you quickly.",
    ],
    website: [
      "Your services, prices and photos of your work in one place",
      "Your salon on Google Maps, with your hours and reviews",
      "A WhatsApp button, so new clients message you in one tap",
    ],
  },
  {
    slug: "restaurants",
    noun: "restaurant",
    name: "Restaurants and food businesses",
    tagline: "Your menu, found in one search.",
    pains: [
      "Your menu and prices online are out of date.",
      "Hungry people nearby find someone else first on Google.",
      "Customers phone just to ask if you're open.",
    ],
    website: [
      "An up-to-date menu, opening hours and directions",
      "A proper Google listing with photos and reviews",
      "A WhatsApp button for orders and table bookings",
    ],
  },
  {
    slug: "caterers",
    noun: "catering or events business",
    name: "Caterers and event companies",
    tagline: "Show your best events, win the next one.",
    pains: [
      "People ask for your menus and photos before they'll book.",
      "Your best events only live on your phone.",
      "Event planners search online and don't find you.",
    ],
    website: [
      "Your menus and photos of past events",
      "An easy way to ask for a quote",
      "Your business on Google when people search for caterers nearby",
    ],
  },
  {
    slug: "guesthouses",
    noun: "guesthouse",
    name: "Guesthouses and B&Bs",
    tagline: "More direct bookings, less commission.",
    pains: [
      "Guests find you only on booking sites, and you pay commission.",
      "Your rooms, rates and photos aren't easy to see in one place.",
      "Guests can't tell how to book with you directly.",
    ],
    website: [
      "Your rooms, rates and photos on your own website",
      "A proper Google listing with your location and reviews",
      "A WhatsApp button for direct bookings, with no commission",
    ],
  },
  {
    slug: "auto-repair",
    noun: "workshop",
    name: "Auto repair shops",
    tagline: "Found when a car needs fixing.",
    pains: [
      "Drivers search for a mechanic nearby and find someone else.",
      "People can't see what you fix or how to reach you.",
      "Your workshop is hard to find on the map.",
    ],
    website: [
      "Your services and the makes you work on",
      "Your workshop on Google Maps, with hours and directions",
      "A WhatsApp button, so drivers can ask for a quote in one tap",
    ],
  },
  {
    slug: "cleaning-security",
    noun: "company",
    name: "Cleaning and security firms",
    tagline: "Look as professional as your team is.",
    pains: [
      "Clients want to check you're a real, established company.",
      "People can't see the services you offer or the areas you cover.",
      "Quote requests come in through too many places.",
    ],
    website: [
      "Your services and the areas you cover",
      "Your company registration and contact details, clearly shown",
      "An easy way to ask for a quote, on WhatsApp or by phone",
    ],
  },
  {
    slug: "tutoring",
    noun: "tutoring centre",
    name: "Tutoring centres",
    tagline: "Parents find you, and trust you.",
    pains: [
      "Parents search for tutoring nearby and don't find you.",
      "Your subjects, times and fees aren't written down anywhere online.",
      "Parents want to know who you are before they call.",
    ],
    website: [
      "Your subjects, times and fees, clearly set out",
      "Your centre on Google Maps, with hours and directions",
      "A WhatsApp button for parents' questions",
    ],
  },
  {
    slug: "gyms",
    noun: "gym",
    name: "Gyms and fitness studios",
    tagline: "Full classes start with being found.",
    pains: [
      "People search for a gym nearby and find a bigger one first.",
      "Your classes, prices and timetable aren't easy to see online.",
      "New members can't tell how to sign up.",
    ],
    website: [
      "Your classes, prices and timetable",
      "A proper Google listing with photos and reviews",
      "A WhatsApp button for sign-up questions",
    ],
  },
];

export const otherBusinesses: Industry = {
  slug: "other-small-businesses",
  noun: "business",
  name: "Other small businesses",
  tagline: "The same way to get found, for any small business.",
  pains: [
    "You're hard to find online, or what people find doesn't look like you.",
    "Your prices, hours and contact details are out of date or missing.",
    "Customers can't tell how to reach you quickly.",
  ],
  website: [
    "A clear website that says what you do, where and for how much",
    "Your business on Google Search and Maps",
    "A WhatsApp button on every page",
  ],
};

export const allSolutions = [...industries, otherBusinesses];

// isiXhosa, reviewed by the founder before it goes live. Tech words stay in English.
type IndustryWords = Pick<Industry, "name" | "tagline" | "noun" | "pains" | "website" | "talkAbout">;
const industriesXh: Record<string, IndustryWords> = {
  salons: {
    noun: "isalon",
    name: "Iisalon nezobuhle",
    tagline: "Kulula ukukufumana, kulula ukubhukisha.",
    talkAbout: "Masithethe ngesalon yakho",
    pains: [
      "Abantu bakhangela isalon ekufutshane, kwaye eyakho ayivelanga.",
      "Amaxabiso akho nomsebenzi wakho zikwiiposti ezindala ze-Instagram.",
      "Abathengi abatsha abazi ukuba bangakufumana njani ngokukhawuleza.",
    ],
    website: [
      "Iinkonzo zakho, amaxabiso neefoto zomsebenzi wakho kwindawo enye",
      "Isalon yakho kwi-Google Maps, kunye neeyure nezimvo zakho",
      "Iqhosha le-WhatsApp, ukuze abathengi abatsha bakuthumelele umyalezo ngokucofa kanye",
    ],
  },
  restaurants: {
    noun: "irestyu",
    name: "Iirestyu namashishini okutya",
    tagline: "Imenyu yakho, ifumaneka ngokukhangela kanye.",
    talkAbout: "Masithethe ngerestyu yakho",
    pains: [
      "Imenyu yakho namaxabiso akwi-intanethi akahlaziywanga.",
      "Abantu abalambileyo abakufutshane bafumana omnye kuqala kwi-Google.",
      "Abathengi bafowuna nje ukubuza ukuba uvulile na.",
    ],
    website: [
      "Imenyu ehlaziyiweyo, iiyure zokuvula nendlela yokufika",
      "Uluhlu olufanelekileyo kwi-Google, olunefoto nezimvo",
      "Iqhosha le-WhatsApp lee-oda nokubhukisha iitafile",
    ],
  },
  caterers: {
    noun: "ishishini lokupheka okanye leminyhadala",
    name: "Abapheki namashishini eminyhadala",
    tagline: "Bonisa iminyhadala yakho emihle, uphumelele elandelayo.",
    talkAbout: "Masithethe ngeshishini lakho lokupheka",
    pains: [
      "Abantu bacela iimenyu neefoto zakho ngaphambi kokuba babhukishe.",
      "Iminyhadala yakho emihle ihlala kwifowuni yakho kuphela.",
      "Abacwangcisi beminyhadala bakhangela kwi-intanethi kwaye abakufumani.",
    ],
    website: [
      "Iimenyu zakho neefoto zeminyhadala odlulileyo",
      "Indlela elula yokucela ikowuti",
      "Ishishini lakho kwi-Google xa abantu bekhangela abapheki abakufutshane",
    ],
  },
  guesthouses: {
    noun: "indlu yeendwendwe",
    name: "Iindlu zeendwendwe nee-B&B",
    tagline: "Ii-booking ezininzi ezithe ngqo, ikomishini encinci.",
    talkAbout: "Masithethe ngendlu yakho yeendwendwe",
    pains: [
      "Iindwendwe zikufumana kwiisayithi zokubhukisha kuphela, kwaye uhlawula ikomishini.",
      "Amagumbi akho, amaxabiso neefoto akabonakali lula kwindawo enye.",
      "Iindwendwe azazi ukuba zingabhukisha njani ngqo nawe.",
    ],
    website: [
      "Amagumbi akho, amaxabiso neefoto kwi-website yakho",
      "Uluhlu olufanelekileyo kwi-Google, olunendawo yakho nezimvo",
      "Iqhosha le-WhatsApp lee-booking ezithe ngqo, ngaphandle kwekomishini",
    ],
  },
  "auto-repair": {
    noun: "igaraji",
    name: "Iigaraji zokulungisa iimoto",
    tagline: "Ifumaneka xa imoto ifuna ukulungiswa.",
    talkAbout: "Masithethe ngegaraji yakho",
    pains: [
      "Abaqhubi bakhangela umakhenikhi okufutshane kwaye bafumana omnye.",
      "Abantu ababoni ukuba ulungisa ntoni okanye bangakufumana njani.",
      "Igaraji yakho kunzima ukuyifumana kwimephu.",
    ],
    website: [
      "Iinkonzo zakho neentlobo zeemoto ozilungisayo",
      "Igaraji yakho kwi-Google Maps, kunye neeyure nendlela yokufika",
      "Iqhosha le-WhatsApp, ukuze abaqhubi bacele ikowuti ngokucofa kanye",
    ],
  },
  "cleaning-security": {
    noun: "inkampani",
    name: "Iinkampani zococeko nezokhuseleko",
    tagline: "Bonakala unobuchule njengeqela lakho.",
    talkAbout: "Masithethe ngenkampani yakho",
    pains: [
      "Abathengi bafuna ukuqinisekisa ukuba uyinkampani yokwenyani nemiselweyo.",
      "Abantu abaziboni iinkonzo ozinikezelayo okanye iindawo ozisebenzayo.",
      "Izicelo zeekowuti zingena ngeendawo ezininzi kakhulu.",
    ],
    website: [
      "Iinkonzo zakho neendawo ozisebenzayo",
      "Ubhaliso lwenkampani yakho neenkcukacha zoqhagamshelwano, zibonakala ngokucacileyo",
      "Indlela elula yokucela ikowuti, kwi-WhatsApp okanye ngefowuni",
    ],
  },
  tutoring: {
    noun: "iziko lokufundisa",
    name: "Amaziko okufundisa",
    tagline: "Abazali bakufumana, kwaye bayakuthemba.",
    talkAbout: "Masithethe ngeziko lakho lokufundisa",
    pains: [
      "Abazali bakhangela abafundisi abakufutshane kwaye abakufumani.",
      "Izifundo zakho, amaxesha neemali azibhalwanga ndawo kwi-intanethi.",
      "Abazali bafuna ukwazi ukuba ungubani ngaphambi kokuba bafowune.",
    ],
    website: [
      "Izifundo zakho, amaxesha neemali, zicaciswe kakuhle",
      "Iziko lakho kwi-Google Maps, kunye neeyure nendlela yokufika",
      "Iqhosha le-WhatsApp lemibuzo yabazali",
    ],
  },
  gyms: {
    noun: "ijim",
    name: "Iijim nezitudiyo zokuzilolonga",
    tagline: "Iiklasi ezigcweleyo ziqala ngokufumaneka.",
    talkAbout: "Masithethe ngejim yakho",
    pains: [
      "Abantu bakhangela ijim ekufutshane kwaye bafumana enkulu kuqala.",
      "Iiklasi zakho, amaxabiso nexesha azibonakali lula kwi-intanethi.",
      "Amalungu amatsha awazi ukuba angabhalisa njani.",
    ],
    website: [
      "Iiklasi zakho, amaxabiso nexesha",
      "Uluhlu olufanelekileyo kwi-Google, olunefoto nezimvo",
      "Iqhosha le-WhatsApp lemibuzo yokubhalisa",
    ],
  },
  "other-small-businesses": {
    noun: "ishishini",
    name: "Amanye amashishini amancinci",
    tagline: "Indlela efanayo yokufumaneka, yalo naliphi na ishishini elincinci.",
    talkAbout: "Masithethe ngeshishini lakho",
    pains: [
      "Kunzima ukukufumana kwi-intanethi, okanye oko abantu bakufumanayo akufani nawe.",
      "Amaxabiso akho, iiyure neenkcukacha zoqhagamshelwano azihlaziywanga okanye azikho.",
      "Abathengi abazi ukuba bangakufumana njani ngokukhawuleza.",
    ],
    website: [
      "I-website ecacileyo ethi wenza ntoni, phi kwaye ngexabiso elingakanani",
      "Ishishini lakho kwi-Google Search nakwi-Maps",
      "Iqhosha le-WhatsApp kulo lonke iphepha",
    ],
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
