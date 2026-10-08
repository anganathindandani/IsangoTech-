interface ImportMetaEnv {
  readonly PUBLIC_SUPABASE_FUNCTIONS_URL?: string;
  readonly PUBLIC_TURNSTILE_SITE_KEY?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
