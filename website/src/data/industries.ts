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
    noun: "catering or events business",
    name: "Caterers and event companies",
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
  {
    slug: "auto-repair",
    noun: "workshop",
    name: "Auto repair shops",
    tagline: "Fewer \"is my car ready?\" calls.",
    pains: [
      "Customers phone all day to ask if their car is ready.",
      "Quotes are approved by phone or in person, and the details get lost.",
      "Customers forget their next service, and so does the workshop.",
    ],
    byStage: {
      1: "A website with your services and a WhatsApp button, and your workshop showing up on Google Maps.",
      2: "A WhatsApp assistant that answers questions about services and prices, and books customers in.",
      3: "Digital job cards, quotes approved on WhatsApp, and \"car ready\" updates sent for you.",
      4: "Service-due reminders and invoices that go out by themselves.",
    },
  },
  {
    slug: "cleaning-security",
    noun: "company",
    name: "Cleaning and security firms",
    tagline: "Rosters, check-ins and invoices in one place.",
    pains: [
      "Shift rosters change often, and staff hear about it late.",
      "Site check-ins and incident reports live in WhatsApp groups and paper.",
      "Monthly client invoices take days to put together.",
    ],
    byStage: {
      1: "A website that shows your services and the areas you cover, with an easy way to ask for a quote.",
      2: "Quote requests answered instantly on WhatsApp, with every lead tracked to a contract.",
      3: "Shift rosters, site check-ins and incident reports in one system, with a dashboard for each client site.",
      4: "Monthly client invoicing and incident summaries that put themselves together.",
    },
  },
  {
    slug: "tutoring",
    noun: "tutoring centre",
    name: "Tutoring centres",
    tagline: "Fees paid on time, parents kept in the loop.",
    pains: [
      "Following up on school fees takes hours every month.",
      "Timetables change, and parents hear about it too late.",
      "Parents ask how their child is doing, and the answers live in notebooks.",
    ],
    byStage: {
      1: "A website with your subjects, times and fees, and a WhatsApp button for parents.",
      2: "Parents' questions about classes, times and fees answered instantly on WhatsApp, and every enquiry captured.",
      3: "Class timetables, attendance, fee reminders and progress updates to parents, with learners' details kept safe under POPIA.",
      4: "Fee reminders and monthly progress reports that send themselves.",
    },
  },
  {
    slug: "gyms",
    noun: "gym",
    name: "Gyms and fitness studios",
    tagline: "Full classes, fewer missed fees.",
    pains: [
      "Memberships lapse because nobody reminded the member.",
      "Fee arrears are chased by hand.",
      "Class bookings happen in WhatsApp chats and on paper.",
    ],
    byStage: {
      1: "A website with your classes, prices and timetable, and a proper Google listing.",
      2: "Questions about classes, prices and times answered instantly on WhatsApp, with sign-ups captured.",
      3: "Membership sign-ups and renewals, class bookings, arrears reminders and attendance tracking.",
      4: "Renewals, arrears follow-ups and come-back messages to quiet members, running on their own.",
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
    noun: "ishishini lokupheka okanye leminyhadala",
    name: "Abapheki namashishini eminyhadala",
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
  "auto-repair": {
    noun: "igaraji",
    name: "Iigaraji zokulungisa iimoto",
    tagline: "Iifowuni ezimbalwa zokubuza \"ingaba imoto yam ilungile?\"",
    talkAbout: "Masithethe ngegaraji yakho",
    pains: [
      "Abathengi bafowuna imini yonke bebuza ukuba imoto yabo ilungile na.",
      "Iikowuti zivunywa ngefowuni okanye ngobuqu, kwaye iinkcukacha ziyalahleka.",
      "Abathengi bayalibala inkonzo yabo elandelayo, kwanegaraji iyalibala.",
    ],
    byStage: {
      1: "I-website eneenkonzo zakho neqhosha le-WhatsApp, kwaye igaraji yakho ibonakale kwi-Google Maps.",
      2: "I-WhatsApp assistant ephendula imibuzo ngeenkonzo namaxabiso, kwaye ibhukishe abathengi.",
      3: "Iikhadi zemisebenzi zedijithali, iikowuti ezivunywa kwi-WhatsApp, nemiyalezo ethi \"imoto ilungile\" ethunyelwa endaweni yakho.",
      4: "Izikhumbuzo zenkonzo elandelayo nee-invoyisi eziphuma zodwa.",
    },
  },
  "cleaning-security": {
    noun: "inkampani",
    name: "Iinkampani zococeko nezokhuseleko",
    tagline: "Iishifti, ukungena kwiisayithi nee-invoyisi kwindawo enye.",
    talkAbout: "Masithethe ngenkampani yakho",
    pains: [
      "Iishifti zabasebenzi zitshintsha rhoqo, kwaye abasebenzi beva emva kwexesha.",
      "Ukungena kwiisayithi neengxelo zeziganeko zigcinwe kumaqela e-WhatsApp nakumaphepha.",
      "Ii-invoyisi zabathengi zenyanga zithatha iintsuku ukuzilungisa.",
    ],
    byStage: {
      1: "I-website ebonisa iinkonzo zakho neendawo ozisebenzayo, enendlela elula yokucela ikowuti.",
      2: "Izicelo zeekowuti ziphendulwa ngoko nangoko kwi-WhatsApp, kwaye umthengi ngamnye onokubakho ulandelwa ade abe sisivumelwano.",
      3: "Iishifti zabasebenzi, ukungena kwiisayithi neengxelo zeziganeko kwinkqubo enye, ne-dashboard yesayithi nganye yomthengi.",
      4: "Ii-invoyisi zenyanga zabathengi nezishwankathelo zeziganeko ezizilungiselelayo.",
    },
  },
  tutoring: {
    noun: "iziko lokufundisa",
    name: "Amaziko okufundisa",
    tagline: "Iimali zihlawulwa ngexesha, abazali bahlala besazi.",
    talkAbout: "Masithethe ngeziko lakho lokufundisa",
    pains: [
      "Ukulandelela iimali zesikolo kuthatha iiyure inyanga nganye.",
      "Amaxesha eeklasi ayatshintsha, kwaye abazali beva emva kwexesha.",
      "Abazali babuza ukuba umntwana wabo uqhuba njani, kwaye iimpendulo zisezincwadini.",
    ],
    byStage: {
      1: "I-website enezifundo zakho, amaxesha neemali, neqhosha le-WhatsApp labazali.",
      2: "Imibuzo yabazali ngeeklasi, amaxesha neemali iphendulwa ngoko nangoko kwi-WhatsApp, kwaye wonke umbuzo ubhalwa.",
      3: "Amaxesha eeklasi, ubukho, izikhumbuzo zemali neengxelo zenkqubela kubazali, neenkcukacha zabafundi zigcinwe zikhuselekile ngokwe-POPIA.",
      4: "Izikhumbuzo zemali neengxelo zenkqubela zenyanga ezizithumelayo.",
    },
  },
  gyms: {
    noun: "ijim",
    name: "Iijim nezitudiyo zokuzilolonga",
    tagline: "Iiklasi ezigcweleyo, iimali ezimbalwa eziphosiweyo.",
    talkAbout: "Masithethe ngejim yakho",
    pains: [
      "Ubulungu buyaphelelwa kuba akukho mntu ukhumbuze ilungu.",
      "Amatyala eemali alandelwa ngesandla.",
      "Ukubhukisha iiklasi kwenzeka kwiingxoxo ze-WhatsApp nakumaphepha.",
    ],
    byStage: {
      1: "I-website eneeklasi zakho, amaxabiso nexesha, kunye noluhlu olufanelekileyo kwi-Google.",
      2: "Imibuzo ngeeklasi, amaxabiso namaxesha iphendulwa ngoko nangoko kwi-WhatsApp, kwaye ababhalisayo babhalwa.",
      3: "Ukubhalisa nokuhlaziya ubulungu, ukubhukisha iiklasi, izikhumbuzo zamatyala nokulandelela ubukho.",
      4: "Ukuhlaziya, ukulandelela amatyala nemiyalezo yokubuya kumalungu angasafiki, kusebenza ngokwakho.",
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
