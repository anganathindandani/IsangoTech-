// Serves Meta's domain verification file exactly as Meta asks for it. Static
// assets drop ".html" from addresses (a redirect), which Meta's check refuses,
// so this one path is answered here; everything else is the built site.
const META_VERIFICATION = "/bq3jaax82hsxmiqigqlbbwoagw1b7f.html";

export default {
  fetch(request, env) {
    if (new URL(request.url).pathname === META_VERIFICATION) {
      return new Response("bq3jaax82hsxmiqigqlbbwoagw1b7f", {
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }
    return env.ASSETS.fetch(request);
  },
};
