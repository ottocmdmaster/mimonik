#!/bin/bash
# Najde nejnovější PDF (konvence MMYY.pdf nebo MM+MMYY.pdf), roztrha na JPG a aktualizuje strany.json
set -e

cd "$(dirname "$0")/html"

# Najdi nejnovější PDF — podporuje MMYY.pdf i MM+MMYY.pdf (dvojčísla)
newest=""
newest_val=0

for pdf in images/pdf/*.pdf; do
  base=$(basename "$pdf")
  [ -f "$pdf" ] || continue
  name="${base%.pdf}"

  if [[ "$name" =~ ^([0-9]{2})\+([0-9]{2})([0-9]{2})$ ]]; then
    # Dvojčíslo: 03+0425 → mm1=03, mm2=04, yy=25, řadí se podle pozdějšího měsíce
    mm="${BASH_REMATCH[2]}"
    yy="${BASH_REMATCH[3]}"
  elif [[ "$name" =~ ^([0-9]{2})([0-9]{2})$ ]]; then
    # Jednoduché: 0625 → mm=06, yy=25
    mm="${BASH_REMATCH[1]}"
    yy="${BASH_REMATCH[2]}"
  else
    continue
  fi

  val=$((10#$yy * 100 + 10#$mm))
  if [ "$val" -gt "$newest_val" ]; then
    newest_val="$val"
    newest="$name"
  fi
done

if [ -z "$newest" ]; then
  echo "Žádné PDF s konvencí MMYY.pdf nebo MM+MMYY.pdf nenalezeno."
  exit 1
fi

echo "Nejnovější PDF: ${newest}.pdf"

# Smaž staré JPG stránky
echo "Mažu staré JPG..."
mkdir -p images/strany
rm -f images/strany/M[0-9]*.jpg

# Převeď PDF na JPG stránky
echo "Konvertuji ${newest}.pdf na JPG..."
pdftoppm -jpeg -r 200 "images/pdf/${newest}.pdf" images/strany/M

# Přejmenuj M-01.jpg → M1.jpg, M-02.jpg → M2.jpg (bez pomlčky a leading zeros)
count=0
for f in images/strany/M-*.jpg; do
  [ -f "$f" ] || continue
  count=$((count + 1))
  mv "$f" "images/strany/M${count}.jpg"
done

echo "Vytvořeno $count stránek."
echo "Hotovo!"
