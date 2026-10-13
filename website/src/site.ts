// Business details used across the site. Fill these in as they're confirmed;
// anything left empty is hidden.
export const site = {
  name: "IsangoTech",
  tagline: "Your gateway to smarter business",
  description:
    "IsangoTech helps small businesses in East London and beyond get found, capture customers, run their operations and automate repetitive work.",
  // International format without "+" or spaces, e.g. "27821234567".
  whatsappNumber: "",
  phone: "",
  email: "",
  // The registered company behind the IsangoTech brand (CIPC, 13 October 2026).
  legalName: "Isango Tech (Pty) Ltd",
  companyRegistrationNumber: "2026/817716/07",
  areaServed: "East London, the Eastern Cape and the rest of South Africa",
  googleBusinessProfileUrl: "",
  social: {
    facebook: "",
    instagram: "",
    linkedin: "",
  },
  // Only becomes true once IsangoTech is a registered VAT vendor.
  vatRegistered: false,
  // The privacy policy and terms are drafts until a legal review; they show a
  // notice while this is false.
  legalReviewed: false,
  privacyPolicyVersion: "1",
  privacyPolicyDate: "",
  // Name and email of the Information Officer registered with the Information Regulator.
  informationOfficer: { name: "", email: "" },
  // The About page's "Meet the founder" section stays hidden until name is set.
  // Each string in story is one paragraph. photo is in public/founder/.
  founder: {
    name: "Anganathi Ndandani",
    role: "Founder",
    photo: "/founder/founder-960.webp",
    photoSmall: "/founder/founder-480.webp",
    // The short version for the home page; story is the full one on About.
    intro:
      "I'm Anganathi, from Ngqamakhwe and based in East London. I started IsangoTech because Eastern Cape businesses deserve to be found, and to be answered. When you work with IsangoTech, you work with me.",
    story: [
      "I'm from Ngqamakhwe in the Eastern Cape, and East London has been home since 2022. I earned my Diploma in ICT Application Development at Walter Sisulu University here in 2025, and I'm now completing my Advanced Diploma while building software for real clients.",
      "I started IsangoTech because Eastern Cape businesses deserve to be found, and to be answered. Too many good salons, guesthouses, restaurants and caterers here are almost invisible online, and the ones people do find often lose customers simply because nobody could reply in time. A message that waits until evening is a booking that went somewhere else. AI changes that: it can answer an enquiry the moment it arrives, book the appointment and send the reminder, while the owner gets on with the work only they can do. It isn't only for big companies any more, and I want small businesses here to have it too.",
      "When you work with IsangoTech, you work with me. I'll explain things in plain language, tell you honestly if you don't need something yet, and stay with you after your system goes live.",
    ],
  },
};

// Website form and slot booking go through these Supabase edge functions.
// Set PUBLIC_SUPABASE_FUNCTIONS_URL (e.g. https://<ref>.supabase.co/functions/v1)
// and PUBLIC_TURNSTILE_SITE_KEY when building for production.
export const formConfig = {
  functionsUrl: import.meta.env.PUBLIC_SUPABASE_FUNCTIONS_URL ?? "",
  turnstileSiteKey: import.meta.env.PUBLIC_TURNSTILE_SITE_KEY ?? "",
};

export const nav = [
  { href: "/solutions", label: { en: "Solutions", xh: "Izisombululo" } },
  { href: "/services", label: { en: "Services and pricing", xh: "Iinkonzo namaxabiso" } },
  { href: "/about", label: { en: "About", xh: "Ngathi" } },
  { href: "/contact", label: { en: "Contact", xh: "Qhagamshelana nathi" } },
];

// The site's own words in each language. The English is the original; the
// isiXhosa is reviewed by the founder before it goes live.
export const siteText = {
  en: {
    tagline: site.tagline,
    description: site.description,
    areaServed: site.areaServed,
    founderRole: site.founder.role,
    founderIntro: site.founder.intro,
    founderStory: site.founder.story,
  },
  xh: {
    tagline: "Isango lakho eliya kwishishini elikrelekrele",
    description:
      "I-IsangoTech incedisa amashishini amancinci eMonti nangaphaya ukuba afumaneke, afumane abathengi, aqhube imisebenzi yawo, kwaye imisebenzi ephindaphindwayo yenzeke ngokuzenzekelayo.",
    areaServed: "EMonti, eMpuma Koloni nakwiindawo ezisele zoMzantsi Afrika",
    founderRole: "Umseki",
    founderIntro:
      "NdinguAnganathi, ndisuka eNgqamakhwe kwaye ndihlala eMonti. Ndaqalisa i-IsangoTech kuba amashishini aseMpuma Koloni afanelwe kukufumaneka, nokuphendulwa. Xa usebenza ne-IsangoTech, usebenza nam.",
    founderStory: [
      "Ndisuka eNgqamakhwe eMpuma Koloni, kwaye iMonti ilikhaya lam ukususela ngo-2022. Ndafumana iDiploma kwi-ICT Application Development kwiYunivesithi iWalter Sisulu apha ngo-2025, kwaye ngoku ndigqibezela iAdvanced Diploma yam ngoxa ndisakha i-software yabathengi bokwenyani.",
      "Ndaqalisa i-IsangoTech kuba amashishini aseMpuma Koloni afanelwe kukufumaneka, nokuphendulwa. Iisalon ezininzi ezilungileyo, iindlu zeendwendwe, iirestyu nabapheki beminyhadala apha phantse abonakali kwi-intanethi, kwaye abo bafumanekayo bahlala bephulukana nabathengi kuba kungekho mntu uphendule ngexesha. Umyalezo olinda de kube ngokuhlwa yi-booking eye kwenye indawo. I-AI iyayitshintsha loo nto: ingaphendula umbuzo kwangoko xa ufika, ibhukishe idinga, ithumele isikhumbuzo, ngoxa umnini eqhubeka nomsebenzi anokuwenza yena kuphela. Ayiseyiyo eyeenkampani ezinkulu kuphela, kwaye ndifuna namashishini amancinci apha ayifumane.",
      "Xa usebenza ne-IsangoTech, usebenza nam. Ndiza kuchaza izinto ngolwimi olucacileyo, ndikuxelele ngokunyaniseka xa ungekayidingi into ethile, kwaye ndihlale nawe emva kokuba inkqubo yakho iqalile ukusebenza.",
    ],
  },
};
