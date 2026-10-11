(function () {
  var stav = document.getElementById("oz-stav");
  var tlacitko = document.getElementById("oz-tlacitko");
  var napoveda = document.getElementById("oz-napoveda");

  var ios = /iPhone|iPad|iPod/.test(navigator.userAgent);
  var nainstalovano = window.navigator.standalone === true ||
    (window.matchMedia && window.matchMedia("(display-mode: standalone)").matches);

  function nastav(text, popis, tlacitkoText, povoleno) {
    stav.textContent = text;
    napoveda.textContent = popis || "";
    tlacitko.textContent = tlacitkoText || "";
    tlacitko.style.display = tlacitkoText ? "" : "none";
    tlacitko.disabled = !povoleno;
  }

  function klic(b64) {
    var pad = "=".repeat((4 - (b64.length % 4)) % 4);
    var raw = atob((b64 + pad).replace(/-/g, "+").replace(/_/g, "/"));
    var out = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out;
  }

  function posli(cesta, sub) {
    return fetch(cesta, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(sub)
    }).then(function (r) { if (!r.ok) throw new Error("server " + r.status); });
  }

  function podpora() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) {
      if (ios && !nainstalovano) {
        nastav("Oznámení vypnuta",
          "Na iPhonu nejdřív otevři tuto stránku v Safari, klepni na tlačítko Sdílet a zvol „Přidat na plochu“. Pak otevři Mimoník z plochy a oznámení zapni tady. Funguje od iPhonu 8 s iOS 16.4 a novějším.", "", false);
      } else {
        nastav("Oznámení tento přístroj nepodporuje",
          ios ? "Oznámení potřebují iPhone 8 nebo novější s iOS 16.4 a novějším (iPhone 7 je neumí). Čtení časopisu funguje dál." : "Prohlížeč oznámení nepodporuje.", "", false);
      }
      return false;
    }
    return true;
  }

  function obnov() {
    if (Notification.permission === "denied") {
      nastav("Oznámení jsou zablokovaná", "Povol je v nastavení telefonu u Mimoníku (Nastavení → Oznámení) a vrať se sem.", "", false);
      return;
    }
    navigator.serviceWorker.ready
      .then(function (reg) { return reg.pushManager.getSubscription(); })
      .then(function (sub) {
        if (sub && Notification.permission === "granted") {
          nastav("Oznámení jsou zapnutá", "Dáme ti vědět, až vyjde nové číslo.", "Vypnout oznámení", true);
          tlacitko.onclick = vypni;
        } else {
          nastav("Oznámení jsou vypnutá", "", "Zapnout oznámení", true);
          tlacitko.onclick = zapni;
        }
      });
  }

  function zapni() {
    tlacitko.disabled = true;
    Notification.requestPermission().then(function (p) {
      if (p !== "granted") return obnov();
      return fetch("/api/push/key").then(function (r) { return r.text(); }).then(function (k) {
        return navigator.serviceWorker.ready.then(function (reg) {
          return reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: klic(k.trim()) });
        });
      }).then(function (sub) {
        return posli("/api/push/subscribe", sub.toJSON());
      }).then(obnov);
    }).catch(function (e) {
      nastav("Zapnutí se nepovedlo", String(e && e.message || e), "Zkusit znovu", true);
    });
  }

  function vypni() {
    tlacitko.disabled = true;
    navigator.serviceWorker.ready
      .then(function (reg) { return reg.pushManager.getSubscription(); })
      .then(function (sub) {
        if (!sub) return;
        var json = sub.toJSON();
        return posli("/api/push/unsubscribe", { endpoint: json.endpoint })
          .catch(function () {})
          .then(function () { return sub.unsubscribe(); });
      })
      .then(obnov)
      .catch(function (e) {
        nastav("Vypnutí se nepovedlo", String(e && e.message || e), "Zkusit znovu", true);
      });
  }

  if (podpora()) {
    navigator.serviceWorker.register("./sw.js").then(obnov);
  }
})();
