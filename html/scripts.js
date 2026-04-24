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

console.log("[secret] script loaded, listening for:", SECRET);

document.addEventListener("keydown", (e) => {
  console.log("[secret] keydown:", e.key, "| buffer before:", buffer);
  if (e.key.length !== 1) return;
  buffer = (buffer + e.key.toLowerCase()).slice(-SECRET.length);
  console.log("[secret] buffer after:", buffer);
  if (buffer === SECRET) {
    console.log("[secret] MATCH! redirecting...");
    window.location.href = "secret.html";
  }
});

const TOKEN_PLATNOST_MS = 30 * 60 * 1000;

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
      if (ulozeneHeslo !== heslo) {
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
      try {
        await fetch("https://formsubmit.co/ajax/mimonik4b@gmail.com", {
          method: "POST",
          headers: { "Content-Type": "application/json", "Accept": "application/json" },
          body: JSON.stringify({
            _subject: "Přihlášení do Mimoníku",
            uzivatel,
            opravneni: opravneni.length ? opravneni.join(",") : "(neuvedeno)",
            token,
            cas: new Date().toISOString(),
            userAgent: navigator.userAgent
          })
        });
      } catch (err) {
        console.warn("Notifikaci o přihlášení se nepodařilo odeslat:", err);
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
    document.getElementById("form-token").value = mimonikToken.token;
    if (opravneni.includes("B")) {
      document.getElementById("upload-form").style.display = "none";
      document.getElementById("zakaz").style.display = "";
    }
    if (opravneni.includes("D")) {
      document.getElementById("github-info").style.display = "";
    }
    const zbyva = TOKEN_PLATNOST_MS - (Date.now() - mimonikToken.vytvoren);
    setTimeout(() => {
      sessionStorage.removeItem("mimonik-token");
      alert("Byl jsi automaticky odhlášen po 30 minutách.");
      window.location.href = "secret.html";
    }, Math.max(0, zbyva));
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
