async function main() {
  let html = "";

  try {
    const response = await fetch("./strany.json");
    const data = await response.json();

    for (let strana = 1; strana <= data.pocet_stran; strana++) {
      html += `
<div id="slide${strana}" class="mySlides fade">
  <img src="./${data.nazev_souboru}${strana}.jpg" alt="${data.nazev_souboru} ${strana}">
</div>
`;
    }

    document.getElementById("blabla").innerHTML = html;

  } catch (error) {
    console.error("Chyba při načítání JSON:", error);
  }
}

main();
