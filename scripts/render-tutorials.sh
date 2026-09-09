#!/usr/bin/env bash
# Render every tutorial by explicit path. A bare `quarto render` would also
# rebuild the decks, and a broken tutorial must never block a deck.
#
#   bash scripts/render-tutorials.sh            # all four
#   bash scripts/render-tutorials.sh pipeline   # one
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -gt 0 ]; then
  names=("$@")
else
  names=(biobouncer biohttp bioclients pipeline)
fi

for n in "${names[@]}"; do
  echo "== tutorials/$n.qmd =="
  quarto render "tutorials/$n.qmd"
done

echo
ls -la tutorials/*.html
