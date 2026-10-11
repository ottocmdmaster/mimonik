const CACHE = "mimonik-v1";
const ZAKLAD = ["./index.html", "./mimonik.css", "./scripts.js", "./oznameni.html", "./images/logo.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ZAKLAD)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((k) => Promise.all(k.filter((n) => n !== CACHE).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

// Nejdřív síť (aby bylo vždy vidět nové číslo), při výpadku uložená kopie.
self.addEventListener("fetch", (e) => {
  const req = e.request;
  const url = new URL(req.url);
  if (req.method !== "GET" || url.origin !== location.origin || url.pathname.indexOf("/api/") === 0) return;
  if (req.headers.has("range")) return;
  e.respondWith(
    fetch(req)
      .then((res) => {
        if (res.ok) {
          const kopie = res.clone();
          caches.open(CACHE).then((c) => c.put(req, kopie));
        }
        return res;
      })
      .catch(() => caches.match(req).then((r) => r || caches.match("./index.html")))
  );
});

self.addEventListener("push", (e) => {
  e.waitUntil(
    self.registration.showNotification("Nový Mimoník", {
      body: "Vyšlo nové číslo časopisu. Klepni a přečti si ho.",
      icon: "./images/ikony/ikona-192.png",
      tag: "nove-cislo"
    })
  );
});

self.addEventListener("notificationclick", (e) => {
  e.notification.close();
  e.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((okna) => {
      for (const o of okna) {
        if ("focus" in o) { o.navigate("./index.html"); return o.focus(); }
      }
      return self.clients.openWindow("./index.html");
    })
  );
});
