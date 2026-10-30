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
    package: "WhatsApp Assistant",
    nextStep: "Run daily operations in one system",
  },
  {
    number: 3,
    name: "Run operations",
    whereYouAre: "We run the business on spreadsheets, paper and WhatsApp groups.",
    need: "Replace spreadsheets and WhatsApp threads",
    offer: "Bookings and orders in one system, with a dashboard that shows your sales, busy times and regulars.",
    package: "Business Portal",
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

// isiXhosa, reviewed by the founder before it goes live.
const stagesXh: Record<number, Omit<Stage, "number">> = {
  1: {
    name: "Fumaneka",
    whereYouAre: "Abantu abasifumani kwi-intanethi, okanye oko bakufumanayo akubonisi thina.",
    need: "Bonakala kwaye uthembeke",
    offer: "I-website, i-Google Business Profile yakho isetwe kakuhle, neqhosha le-WhatsApp ukuze abantu bakufumane ngokucofa kanye.",
    package: "I-website yokuqalisa",
    nextStep: "Bamba imibuzo ngendlela efanelekileyo",
  },
  2: {
    name: "Bamba uphendule",
    whereYouAre: "Imibuzo iyangena, kodwa eminye iyalahleka.",
    need: "Yeka ukuphulukana nemibuzo",
    offer: "I-WhatsApp assistant ephendula wonke umbuzo ngoko nangoko xa ufika, kunye nezikhumbuzo ukuze abathengi bafike.",
    package: "WhatsApp Assistant",
    nextStep: "Qhuba imisebenzi yemihla ngemihla kwinkqubo enye",
  },
  3: {
    name: "Qhuba imisebenzi",
    whereYouAre: "Siqhuba ishishini ngee-spreadsheet, amaphepha namaqela e-WhatsApp.",
    need: "Tshintsha ii-spreadsheet nemicu ye-WhatsApp",
    offer: "Ii-booking nee-oda kwinkqubo enye, ne-dashboard ebonisa intengiso yakho, amaxesha axakekileyo nabathengi abaqhelekileyo.",
    package: "Business Portal",
    nextStep: "Yenza imisebenzi ephindaphindwayo ngokuzenzekelayo",
  },
  4: {
    name: "Yenza ngokuzenzekelayo",
    whereYouAre: "Iinkqubo zethu ziyasebenza, kodwa imisebenzi efanayo itya iiyure veki nganye.",
    need: "Onga ixesha, ukhonze abathengi abaninzi",
    offer: "I-AI Readiness Assessment yokufumanisa into efanele ukwenziwa ngokuzenzekelayo, emva koko i-automation ekususela imisebenzi ephindaphindwayo.",
    package: "I-AI Readiness Assessment, emva koko ii-automation add-ons",
    nextStep: "Ukuphucula okuqhubekayo",
  },
};

/** The stages in the page's language. */
export function stagesFor(lang: "en" | "xh"): Stage[] {
  return lang === "en" ? stages : stages.map((s) => ({ number: s.number, ...stagesXh[s.number] }));
}

export function stageByNumber(n: number, lang: "en" | "xh" = "en"): Stage | undefined {
  return stagesFor(lang).find((s) => s.number === n);
}
