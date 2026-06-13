#!/usr/bin/env bash
# shell/motd/render-portraits.sh — (re)render the character portraits in
# art/portraits/*.png into pre-coloured terminal art at art/<name>.ans.
#
# These .ans files are the ZERO-DEPENDENCY fallback: any host without chafa
# still gets a colourful portrait in the MOTD. Where chafa IS installed, motd.sh
# renders the .png live instead (adapts to the terminal's size + colour depth),
# so you rarely need to re-run this — only when you add/replace a portrait PNG.
#
# Needs chafa (sudo dnf/apt install chafa, or shell/install.sh --with-fonts).
#
# Usage:
#   ./render-portraits.sh                 # all PNGs -> .ans (truecolor, w=30)
#   ./render-portraits.sh --width 24      # narrower
#   ./render-portraits.sh --colors 256    # 256-colour instead of truecolor
#   ./render-portraits.sh bender fry       # only these

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PNGDIR="$DIR/art/portraits"
WIDTH=30; HEIGHT=22; COLORS=full; ONLY=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --width) WIDTH="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --colors) COLORS="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ONLY+=("$1"); shift ;;
  esac
done

command -v chafa >/dev/null || { echo "chafa not found — install it (shell/install.sh --with-fonts)"; exit 1; }

shopt -s nullglob
count=0
for png in "$PNGDIR"/*.png; do
  name="$(basename "$png" .png)"
  if [[ ${#ONLY[@]} -gt 0 ]]; then
    printf '%s\n' "${ONLY[@]}" | grep -qx "$name" || continue
  fi
  chafa --format symbols --symbols vhalf+space -c "$COLORS" \
        --size "${WIDTH}x${HEIGHT}" --align top,left "$png" > "$DIR/art/$name.ans"
  echo "  art/$name.ans"
  count=$((count+1))
done
echo "rendered $count portrait(s) at ${WIDTH}x${HEIGHT} ($COLORS)."
