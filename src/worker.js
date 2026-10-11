// Mimoník: ukládání odběrů a rozesílání upozornění o novém čísle (Web Push s VAPID, bez těla zprávy).
// Bindingy: SUBS (KV), VAPID_PUBLIC, VAPID_PRIVATE_JWK, NOTIFY_TOKEN, ASSETS.

const SUBJECT = "mailto:mimonik4b@gmail.com";

const b64u = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function idOdberu(endpoint) {
  const h = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(endpoint));
  return "sub:" + b64u(h);
}

function platnyEndpoint(e) {
  try {
    return typeof e === "string" && e.length < 1000 && new URL(e).protocol === "https:";
  } catch (_) {
    return false;
  }
}

async function vapidHlavicka(env, endpoint) {
  const aud = new URL(endpoint).origin;
  const hlava = b64u(new TextEncoder().encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const telo = b64u(
    new TextEncoder().encode(JSON.stringify({ aud, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: SUBJECT }))
  );
  const klic = await crypto.subtle.importKey(
    "jwk", JSON.parse(env.VAPID_PRIVATE_JWK), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]
  );
  const podpis = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, klic, new TextEncoder().encode(hlava + "." + telo));
  return `vapid t=${hlava}.${telo}.${b64u(podpis)}, k=${env.VAPID_PUBLIC}`;
}

async function rozesli(env) {
  let poslano = 0, smazano = 0, chyb = 0, cursor;
  do {
    const strana = await env.SUBS.list({ prefix: "sub:", cursor });
    cursor = strana.list_complete ? undefined : strana.cursor;
    await Promise.all(strana.keys.map(async (k) => {
      const sub = await env.SUBS.get(k.name, "json");
      if (!sub) return;
      try {
        const res = await fetch(sub.endpoint, {
          method: "POST",
          headers: { Authorization: await vapidHlavicka(env, sub.endpoint), TTL: "259200", Urgency: "normal" }
        });
        if (res.status === 404 || res.status === 410) { await env.SUBS.delete(k.name); smazano++; }
        else if (res.ok) poslano++;
        else chyb++;
      } catch (_) {
        chyb++;
      }
    }));
  } while (cursor);
  return { poslano, smazano, chyb };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith("/api/")) return env.ASSETS.fetch(request);

    if (url.pathname === "/api/push/key" && request.method === "GET") {
      return new Response(env.VAPID_PUBLIC, { headers: { "Content-Type": "text/plain" } });
    }

    if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });

    if (url.pathname === "/api/push/subscribe" || url.pathname === "/api/push/unsubscribe") {
      let data;
      try { data = await request.json(); } catch (_) { return new Response("Bad JSON", { status: 400 }); }
      if (!platnyEndpoint(data.endpoint)) return new Response("Bad endpoint", { status: 400 });
      const id = await idOdberu(data.endpoint);
      if (url.pathname.endsWith("/unsubscribe")) {
        await env.SUBS.delete(id);
      } else {
        if (!data.keys || !data.keys.p256dh || !data.keys.auth) return new Response("Bad keys", { status: 400 });
        await env.SUBS.put(id, JSON.stringify({ endpoint: data.endpoint, keys: data.keys }));
      }
      return new Response("ok");
    }

    if (url.pathname === "/api/push/notify") {
      const ocekavany = "Bearer " + env.NOTIFY_TOKEN;
      if (!env.NOTIFY_TOKEN || request.headers.get("Authorization") !== ocekavany) {
        return new Response("Unauthorized", { status: 401 });
      }
      return Response.json(await rozesli(env));
    }

    return new Response("Not found", { status: 404 });
  }
};
