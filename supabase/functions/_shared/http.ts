// CORS and JSON helpers shared by the public edge functions.

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ??
  "https://isangotech.co.za,https://www.isangotech.co.za")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": allowedOrigins.includes(origin) ? origin : allowedOrigins[0],
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "content-type",
    "Vary": "Origin",
  };
}

export function json(
  req: Request,
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json", ...headers },
  });
}
