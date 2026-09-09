#!/usr/bin/env bash
# Render one deck (or all of them) to HTML, then to a PDF backup.
#
#   bash scripts/build-decks.sh main
#   bash scripts/build-decks.sh all
#
# `quarto render --to pdf` does NOT work for revealjs: it routes to the
# LaTeX/beamer pipeline. Reveal's PDF export is a browser print of the
# ?print-pdf route, so this drives headless Chrome directly.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:-main}"
if [ "$NAME" = "all" ]; then
  for d in main biobouncer biohttp bioclients; do
    bash "$0" "$d"
  done
  exit 0
fi

DECK="slides/$NAME.qmd"
[ -f "$DECK" ] || { echo "no such deck: $DECK" >&2; exit 1; }

# Chrome: an explicit CHROME env var wins, then the usual install locations.
CHROME="${CHROME:-}"
if [ -z "$CHROME" ]; then
  for c in \
    "/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "$(command -v google-chrome || true)" \
    "$(command -v chromium || true)"; do
    [ -n "$c" ] && [ -x "$c" ] && { CHROME="$c"; break; }
  done
fi

echo "== render HTML: $DECK =="
quarto render "$DECK"

# Chrome wants a Windows path under Git Bash. `cygpath -m` yields E:/... for
# the URL and `cygpath -w` yields E:\... for the output file. On macOS and
# Linux cygpath does not exist and the POSIX path is already right.
HTML="$PWD/slides/$NAME.html"
PDF="$PWD/slides/$NAME.pdf"
if command -v cygpath >/dev/null 2>&1; then
  HTML_URL="file:///$(cygpath -m "$HTML")"
  PDF_OUT="$(cygpath -w "$PDF")"
else
  HTML_URL="file://$HTML"
  PDF_OUT="$PDF"
fi

echo "== render PDF backup =="
if [ -z "$CHROME" ] || [ ! -x "$CHROME" ]; then
  echo "Chrome not found. Manual route: open '$HTML?print-pdf', print to PDF," >&2
  echo "Landscape, Margins None, Background graphics ON." >&2
  exit 1
fi

# ?print-pdf is MANDATORY. Without it reveal stays in single-viewport mode and
# the PDF has one page. --virtual-time-budget must exceed the time to lay out
# and decode every embedded image; raise it if the output comes out blank.
"$CHROME" \
  --headless=new \
  --disable-gpu \
  --run-all-compositor-stages-before-draw \
  --virtual-time-budget=60000 \
  --no-pdf-header-footer \
  --print-to-pdf="$PDF_OUT" \
  "$HTML_URL?print-pdf" 2>&1 | grep -viE 'devtools|bluetooth|voice|gpu|deprecat' || true

if [ -s "$PDF" ]; then
  echo "ok  $PDF  ($(wc -c < "$PDF" | tr -d ' ') bytes)"
else
  echo "PDF is empty. Fall back to the manual print route (see above)." >&2
  exit 1
fi
