#!/usr/bin/env bash
# Renders VISION.md to a real PDF.
#
#   ./scripts/make-vision-pdf.sh [output.pdf]
#
# Defaults to ~/Desktop/Frij-Vision.pdf. Markdown becomes styled HTML via
# scripts/md2html.py, then headless Chrome prints it — no Homebrew installs,
# no LaTeX, nothing to set up beyond having Chrome.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/VISION.md"
OUT="${1:-$HOME/Desktop/Frij-Vision.pdf}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

[ -f "$SRC" ] || { echo "error: $SRC not found"; exit 1; }
[ -x "$CHROME" ] || {
  echo "error: Google Chrome not found at:"
  echo "  $CHROME"
  echo "Chrome does the HTML-to-PDF step. Install it, or edit CHROME above."
  exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

python3 "$REPO/scripts/md2html.py" "$SRC" "$TMP/vision.html" >/dev/null

"$CHROME" --headless --disable-gpu --no-pdf-header-footer \
  --virtual-time-budget=6000 --print-to-pdf="$OUT" \
  "file://$TMP/vision.html" >/dev/null 2>&1

# Chrome exits 0 even when it writes nothing useful, so check the real output.
if [ ! -s "$OUT" ] || ! file "$OUT" | grep -q "PDF document"; then
  echo "error: no valid PDF was produced at $OUT"
  exit 1
fi

echo "✓ $(file -b "$OUT")"
echo "  $OUT"
