// Industries, open assessment slots and the current privacy policy version for
// the Get started form. Nothing personal; cached for a minute.
import { json } from "../_shared/http.ts";
import { supabase } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: json(req, null).headers });
  if (req.method !== "GET") return json(req, { error: "Method not allowed" }, 405);

  const { data, error } = await supabase.rpc("enquiry_options");
  if (error) {
    console.error("enquiry_options failed", error);
    return json(req, { error: "Could not load the form options" }, 500);
  }
  return json(req, data, 200, { "Cache-Control": "public, max-age=60" });
});
