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

# Aktualizuj odkaz na aktuální číslo v stahovani.html
MESICE=(leden únor březen duben květen červen červenec srpen září říjen listopad prosinec)

if [[ "$newest" =~ ^([0-9]{2})\+([0-9]{2})([0-9]{2})$ ]]; then
  mm1=$((10#${BASH_REMATCH[1]}))
  mm2=$((10#${BASH_REMATCH[2]}))
  yy="${BASH_REMATCH[3]}"
  label="${MESICE[$((mm1-1))]}+${MESICE[$((mm2-1))]} $((2000 + 10#$yy))"
elif [[ "$newest" =~ ^([0-9]{2})([0-9]{2})$ ]]; then
  mm=$((10#${BASH_REMATCH[1]}))
  yy="${BASH_REMATCH[2]}"
  label="${MESICE[$((mm-1))]} $((2000 + 10#$yy))"
fi

python3 - "$label" "images/pdf/${newest}.pdf" <<'PY'
import re
import sys

label, pdf_rel = sys.argv[1], sys.argv[2]
path = "stahovani.html"

with open(path, encoding="utf-8") as f:
    content = f.read()

marker = "<h1>ČÍSLA KE STAŽENÍ</h1>"
end_marker = '<script src="./scripts.js"></script>'

entries_start = content.index("<h2>", content.index(marker))
entries_end = content.index(end_marker)

head = content[:entries_start]
tail = content[entries_end:]
blob = content[entries_start:entries_end]

entry_re = re.compile(r'<h2>(.*?)</h2>\s*<p>\s*(.*?)\s*<p>\s*', re.S)
entries = entry_re.findall(blob)

new_line = f'<a href="./{pdf_rel}" target="_blank" >klikněte zde pro zobrazení čísla</a>'

found = False
new_entries = []
for lbl, cont in entries:
    if lbl.strip() == label:
        new_entries.append((lbl, new_line))
        found = True
    else:
        new_entries.append((lbl, cont.strip()))

if not found:
    new_entries.insert(0, (label, new_line))

rebuilt = "".join(f"<h2>{lbl}</h2>\n<p>\n    {cont}\n<p>\n" for lbl, cont in new_entries)
new_full = head + rebuilt + tail

if new_full != content:
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_full)
    print(f"stahovani.html aktualizováno pro: {label}")
else:
    print(f"stahovani.html už bylo aktuální pro: {label}")
PY

echo "Hotovo!"
