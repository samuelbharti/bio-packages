#!/usr/bin/env bash
# Sanity gate for a rendered deck. One convention holds everything together:
#   deck image refs are always ../assets/...     (relative to slides/)
#   tutorial refs are always assets/... data/... (relative to the repo root)
#
# Check 5 is the one that matters: it PROVES the deck is self-contained, which
# is the whole reason for embed-resources: true.
#
#   bash scripts/check-assets.sh main
set -uo pipefail
cd "$(dirname "$0")/.."

NAME="${1:-main}"
DECK="slides/$NAME.qmd"
HTML="slides/$NAME.html"
PDF="slides/$NAME.pdf"
[ -f "$DECK" ] || { echo "no such deck: $DECK"; exit 1; }
fail=0

PY=$(command -v python3 || command -v python) || {
  echo "no python on PATH, checks 5a and 6 cannot run"; exit 1; }

echo "== 1. deck image refs resolve from slides/ =="
while IFS= read -r p; do
  [ -z "$p" ] && continue
  if [ -f "slides/$p" ]; then echo "  ok      $p"; else echo "  MISSING $p"; fail=1; fi
done < <(grep -ohE '\.\./assets/[A-Za-z0-9._/-]+\.(png|jpg|jpeg|svg|gif)' "$DECK" | sort -u)

echo "== 2. tutorial refs resolve from the repo root =="
while IFS= read -r p; do
  [ -z "$p" ] && continue
  if [ -f "$p" ]; then echo "  ok      $p"; else echo "  MISSING $p"; fail=1; fi
done < <(grep -ohE '(assets|data|fixtures)/[A-Za-z0-9._/-]+\.(png|jpg|jpeg|svg|gif|csv|json)' tutorials/*.qmd | sort -u)

echo "== 3. truncated or empty assets =="
found=$(find assets -type f \( -size -1k -o -empty \) 2>/dev/null)
[ -n "$found" ] && { echo "$found" | sed 's/^/  SUSPECT: /'; fail=1; } || echo "  none"

echo "== 4. committed but unused assets (information, not an error) =="
n=0
while IFS= read -r f; do
  b=$(basename "$f")
  grep -qr -- "$b" slides/*.qmd tutorials/*.qmd 2>/dev/null || { echo "  unused: $f"; n=$((n+1)); }
done < <(find assets -type f ! -name '.DS_Store' | sort)
echo "  ($n unused)"

echo "== 5a. did custom.scss reach the deck? =="
# Do NOT grep the HTML for selectors. embed-resources inlines stylesheets as
# percent-encoded data: URIs, so a plain grep gives a false negative.
if [ -f "$HTML" ]; then
  "$PY" scripts/extract-css.py "$HTML" \
    .kicker .payoff .bignums .cards .flow .pills .chip .walls .verbatim || fail=1
else
  echo "  $HTML not rendered yet"; fail=1
fi

echo "== 5. is the rendered deck self-contained? =="
if [ -f "$HTML" ]; then
  ext=$(grep -o 'src="[^"]*"' "$HTML" | grep -v '^src="data:' | grep -v '\${' | sort -u)
  if [ -n "$ext" ]; then echo "$ext" | sed 's/^/  EXTERNAL REF: /'; fail=1; else echo "  ok, every src= is a data: URI"; fi
  bg=$(grep -o 'data-background-image="[^"]*"' "$HTML" | grep -v 'data:' | sort -u)
  if [ -n "$bg" ]; then echo "$bg" | sed 's/^/  UNEMBEDDED BACKGROUND: /'; fail=1; else echo "  ok, backgrounds embedded"; fi
  gf=$(grep -c 'fonts.googleapis.com' "$HTML")
  echo "  googlefonts refs: $gf  (0 = fully offline; >0 = will try the network)"
else
  echo "  $HTML not rendered yet"; fail=1
fi

echo "== 6. size and page count =="
ls -lh "$HTML" "$PDF" 2>/dev/null | sed 's/^/  /'
if [ -f "$HTML" ]; then
  # 100 MB is GitHub's hard per-file limit, so this gate means "can still be
  # committed". wc -c rather than stat, which differs between BSD and GNU.
  LIMIT_MB=100
  bytes=$(wc -c < "$HTML" | tr -d ' ')
  mb=$(( (bytes * 10 + 524288) / 1048576 ))
  if [ "$bytes" -gt $((LIMIT_MB * 1048576)) ]; then
    echo "  OVER GATE: $((mb / 10)).$((mb % 10)) MB > ${LIMIT_MB} MB"; fail=1
  else echo "  ok, $((mb / 10)).$((mb % 10)) MB, under the ${LIMIT_MB} MB gate"; fi
fi
slides=$(grep -cE '^## ' "$DECK")
echo "  content slides in qmd: $slides (+1 title = $((slides + 1)) expected PDF pages)"
if [ -f "$PDF" ]; then
  pages=$("$PY" -c "import re,sys;print(len(re.findall(rb'/Type\s*/Page[^s]',open(sys.argv[1],'rb').read())))" "$PDF")
  want=$((slides + 1))
  if [ "$pages" -eq "$want" ]; then echo "  ok, PDF is $pages pages"
  else echo "  PAGE COUNT MISMATCH: PDF has $pages, expected $want (a slide is spilling)"; fail=1; fi
fi

echo
[ "$fail" -eq 0 ] && echo "PASS" || echo "FAIL, see above"
exit $fail
