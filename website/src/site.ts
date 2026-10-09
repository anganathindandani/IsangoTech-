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
  // Shown in the footer once the business is registered.
  companyRegistrationNumber: "",
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
    story: [
      "I'm from Ngqamakhwe in the Eastern Cape, and East London has been home since 2022. I studied at Walter Sisulu University here, graduated in 2025, and I'm now completing my Advanced Diploma while building software for real clients.",
      "I started IsangoTech because Eastern Cape businesses deserve to be found, and to be answered. Too many good salons, restaurants and caterers here are almost invisible online, and the ones people do find often lose customers simply because nobody could reply in time. A message that waits until evening is a booking that went somewhere else. AI changes that: it can answer an enquiry the moment it arrives, book the appointment and send the reminder, while the owner gets on with the work only they can do. It isn't only for big companies any more, and I want small businesses here to have it too.",
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
  { href: "/solutions", label: "Solutions" },
  { href: "/services", label: "Services and pricing" },
  { href: "/about", label: "About" },
  { href: "/contact", label: "Contact" },
];
