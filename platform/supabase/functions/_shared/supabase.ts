// Service-role client for the platform project. Edge functions reach the
// database only through the assistant_* functions, which check everything
// against the conversation they're given.
import { createClient } from "jsr:@supabase/supabase-js@2";

export const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
