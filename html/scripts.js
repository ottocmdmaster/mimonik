let slideIndex = 1;

function loadImage(src) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(true);
    img.onerror = () => resolve(false);
    img.src = src;
  });
}

async function loadSlides() {
  const container = document.getElementById("blabla");
  if (!container) return;

  let html = "";
  let strana = 1;

  while (await loadImage(`./images/strany/M${strana}.jpg`)) {
    html += `
<div id="slide${strana}" class="mySlides fade">
  <img src="./images/strany/M${strana}.jpg" alt="Strana ${strana}">
</div>
`;
    strana++;
  }

  if (strana === 1) return;

  container.innerHTML = html;
  showSlides(slideIndex);
}

function plusSlides(n) {
  showSlides(slideIndex += n);
}

function currentSlide(n) {
  showSlides(slideIndex = n);
}

function showSlides(n) {
  let slides = document.getElementsByClassName("mySlides");
  let dots = document.getElementsByClassName("dot");
  if (n > slides.length) { slideIndex = 1; }
  if (n < 1) { slideIndex = slides.length; }
  for (let i = 0; i < slides.length; i++) {
    slides[i].style.display = "none";
  }
  for (let i = 0; i < dots.length; i++) {
    dots[i].className = dots[i].className.replace(" active", "");
  }
  slides[slideIndex - 1].style.display = "block";
  if (dots.length > 0) {
    dots[slideIndex - 1].className += " active";
  }
}

loadSlides();

const SECRET = "mniok";
let buffer = "";

document.addEventListener("keydown", (e) => {
  if (e.key.length !== 1) return;
  buffer = (buffer + e.key.toLowerCase()).slice(-SECRET.length);
  if (buffer === SECRET) {
    window.location.href = "secret.html";
  }
});

const TOKEN_PLATNOST_MS = 30 * 60 * 1000;

async function odvozHash(heslo, saltHex, iteraci = 100000) {
  const enc = new TextEncoder();
  const saltBytes = new Uint8Array(saltHex.match(/.{2}/g).map(b => parseInt(b, 16)));
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(heslo), { name: "PBKDF2" }, false, ["deriveBits"]
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt: saltBytes, iterations: iteraci, hash: "SHA-256" },
    key, 256
  );
  return [...new Uint8Array(bits)].map(b => b.toString(16).padStart(2, "0")).join("");
}

async function overHeslo(ulozene, zadane) {
  if (ulozene.startsWith("pbkdf2$")) {
    const [, iter, salt, hash] = ulozene.split("$");
    const vypocteny = await odvozHash(zadane, salt, parseInt(iter, 10));
    return vypocteny === hash;
  }
  return ulozene === zadane;
}

function nactiToken() {
  try {
    const raw = sessionStorage.getItem("mimonik-token");
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (!data.token || !data.uzivatel || !data.vytvoren) return null;
    if (Date.now() - data.vytvoren > TOKEN_PLATNOST_MS) return null;
    return data;
  } catch (e) {
    return null;
  }
}

const loginForm = document.getElementById("login-form");
if (loginForm) {
  loginForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const uzivatel = document.getElementById("login-uzivatel").value.trim();
    const heslo = document.getElementById("login-heslo").value;
    if (!/^[\p{L}\p{N}_-]+$/u.test(uzivatel)) {
      alert("Neplatné uživatelské jméno.");
      return;
    }
    try {
      const res = await fetch(`./uzivatele/${encodeURIComponent(uzivatel)}.txt`, { cache: "no-store" });
      if (!res.ok) {
        alert("Nesprávné přihlašovací údaje.");
        return;
      }
      const radky = (await res.text()).split(/\r?\n/).map(r => r.trim());
      const ulozeneHeslo = radky[0] || "";
      const opravneni = [...new Set(
        (radky[1] || "").toUpperCase().split(/[^A-Z]+/).filter(Boolean)
      )];
      if (opravneni.length === 0) opravneni.push("B");
      if (!(await overHeslo(ulozeneHeslo, heslo))) {
        alert("Nesprávné přihlašovací údaje.");
        return;
      }
      const token = crypto.randomUUID();
      sessionStorage.setItem("mimonik-token", JSON.stringify({
        uzivatel,
        token,
        opravneni,
        vytvoren: Date.now()
      }));
      if (!localStorage.getItem("mimonik-zarizeni")) {
        localStorage.setItem("mimonik-zarizeni", crypto.randomUUID());
        try {
          await fetch("https://formsubmit.co/ajax/mimonik4b@gmail.com", {
            method: "POST",
            headers: { "Content-Type": "application/json", "Accept": "application/json" },
            body: JSON.stringify({
              _subject: "Přihlášení do Mimoníku z nového zařízení",
              uzivatel,
              cas: new Date().toISOString(),
              userAgent: navigator.userAgent
            })
          });
        } catch (err) {
          console.warn("Notifikaci o přihlášení se nepodařilo odeslat:", err);
        }
      }
      window.location.href = "uzivatel.html";
    } catch (err) {
      alert("Nepodařilo se ověřit přihlášení.");
    }
  });
}

const pozdravEl = document.getElementById("pozdrav");
if (pozdravEl) {
  const mimonikToken = nactiToken();
  if (!mimonikToken) {
    sessionStorage.removeItem("mimonik-token");
    window.location.replace("secret.html");
  } else {
    const opravneni = Array.isArray(mimonikToken.opravneni)
      ? mimonikToken.opravneni
      : (mimonikToken.opravneni ? [mimonikToken.opravneni] : []);
    pozdravEl.textContent = `Ahoj ${mimonikToken.uzivatel.replace(/_/g, " ")}!`;
    document.getElementById("opravneni").textContent = opravneni.length
      ? `Oprávnění: ${opravneni.join(", ")}`
      : "Oprávnění: (neuvedeno)";
    document.getElementById("form-uzivatel").value = mimonikToken.uzivatel;
    if (opravneni.includes("B")) {
      document.getElementById("upload-form").style.display = "none";
      document.getElementById("zakaz").style.display = "";
    }
    if (opravneni.includes("D")) {
      document.getElementById("github-info").style.display = "";
    }
    const konec = mimonikToken.vytvoren + TOKEN_PLATNOST_MS;
    const odpocetEl = document.getElementById("odpocet");
    const aktualizujOdpocet = () => {
      const zbyva = konec - Date.now();
      if (zbyva <= 0) {
        sessionStorage.removeItem("mimonik-token");
        alert("Byl jsi automaticky odhlášen po 30 minutách.");
        window.location.href = "secret.html";
        return;
      }
      const minuty = Math.floor(zbyva / 60000);
      const sekundy = Math.floor((zbyva % 60000) / 1000);
      if (odpocetEl) {
        odpocetEl.textContent = `Zbývá: ${minuty}:${String(sekundy).padStart(2, "0")}`;
      }
    };
    aktualizujOdpocet();
    setInterval(aktualizujOdpocet, 1000);
  }
  const odhlasitBtn = document.getElementById("odhlasit");
  if (odhlasitBtn) {
    odhlasitBtn.addEventListener("click", () => {
      sessionStorage.removeItem("mimonik-token");
      window.location.href = "secret.html";
    });
  }
}

const nahraniForm = document.getElementById("nahrani-form");
if (nahraniForm) {
  nahraniForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    const form = e.target;
    const zadane = document.getElementById("heslo").value.trim();
    try {
      const res = await fetch("./kody.txt", { cache: "no-store" });
      const text = await res.text();
      const hesla = text.split(/\r?\n/).map(h => h.trim()).filter(Boolean);
      if (!hesla.includes(zadane)) {
        alert("Nesprávné heslo.");
        return;
      }
      form.submit();
    } catch (err) {
      alert("Nepodařilo se ověřit heslo.");
    }
  });
}
