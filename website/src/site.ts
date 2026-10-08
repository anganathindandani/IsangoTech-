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
  founder: {
    name: "",
    role: "Founder",
    bio: "",
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
