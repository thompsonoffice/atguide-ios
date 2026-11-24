#!/bin/bash
# Launch the Mac app once per scene and save real-window PNGs, padded to 1280x800.
# Usage: macos_screenshots.sh /path/to/ATGuide.app /path/to/output-dir
set -euo pipefail

APP="${1:?app path required}"
OUT="${2:?output directory required}"
BIN="$APP/Contents/MacOS/ATGuide"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ ! -x "$BIN" ]; then
  echo "No executable at $BIN" >&2
  exit 1
fi

mkdir -p "$OUT"

# The GitHub-hosted runner does not include Pillow; we need it to pad 1280x684 windows to 1280x800.
python3 -c "from PIL import Image" 2>/dev/null || python3 -m pip install --user --quiet Pillow

capture() {
  local scene="$1"
  local name="$2"
  local dest="$OUT/${name}.png"
  rm -f "$dest"
  echo "Capturing $scene -> $dest"
  "$BIN" -ATGuideScreenshot "$scene" -ATGuideScreenshotPath "$dest" &
  local pid=$!
  local i
  for i in $(seq 1 60); do
    if [ -s "$dest" ]; then
      break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 0.5
  done
  wait "$pid" || true
  if [ ! -s "$dest" ]; then
    echo "Failed to write $dest" >&2
    exit 1
  fi
  sips -g pixelWidth -g pixelHeight "$dest"
  python3 "$HERE/pad_mac_screenshot.py" "$dest"
  sips -g pixelWidth -g pixelHeight "$dest"
}

capture browse 01-browse
capture notetakers 02-notetakers
capture device 03-braillenote-touch
capture search 04-search
capture compare 05-compare
capture favorites 06-favorites
capture about 07-about

echo "Wrote screenshots to $OUT"
ls -la "$OUT"
python3 "$HERE/verify_mac_screenshots.py" "$OUT"
