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
