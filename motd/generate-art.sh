#!/usr/bin/env bash
# shell/motd/generate-art.sh — mint new BBS-style banners for the MOTD shuffle.
#
# Uses figlet (wordmark) + optionally lolcat (truecolor gradient) to render
# Futurama catchphrases into pre-coloured .ans files under art/generated/, which
# the MOTD then picks up automatically in shuffle/daily mode. Everything is
# optional: with no tools installed it prints how to get them and exits 0.
#
# Get the tools:   shell/install.sh --with-fonts   (or dnf/apt install figlet lolcat)
#
# Usage:
#   generate-art.sh --all                 # regenerate the themed banner set
#   generate-art.sh --text "GOOD NEWS"    # one custom banner -> stdout + saved
#   generate-art.sh --text "MOM" --font small --plain
#   generate-art.sh --list-fonts
#
# Generated files live in art/generated/ (git-ignored by default — they're
# reproducible). Commit a favourite into art/ by hand if you want it everywhere.

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTDIR="$DIR/art/generated"
FONT="standard"; PLAIN=false; TEXT=""; ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ALL=true; shift ;;
    --text) TEXT="$2"; shift 2 ;;
    --font) FONT="$2"; shift 2 ;;
    --plain) PLAIN=true; shift ;;
    --list-fonts) figlet -f "" 2>&1 | head -1; ls /usr/share/figlet/ 2>/dev/null | sed 's/\.\(flf\|tlf\)$//' | sort -u | column 2>/dev/null || ls /usr/share/figlet/ 2>/dev/null; exit 0 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if ! command -v figlet >/dev/null 2>&1; then
  cat >&2 <<EOF
figlet not found — nothing to generate.
Install it (and optional lolcat for colour gradients):
  shell/install.sh --with-fonts
  # or:  sudo dnf install figlet lolcat   /   sudo apt-get install figlet lolcat
The shipped hand-drawn art in art/*.txt works fine without this.
EOF
  exit 0
fi

HAS_LOLCAT=false; command -v lolcat >/dev/null 2>&1 && HAS_LOLCAT=true

render() {  # $1 = text -> figlet, optionally colourised, on stdout
  local txt="$1"
  if [[ "$PLAIN" == true || "$HAS_LOLCAT" != true ]]; then
    figlet -f "$FONT" -w 120 "$txt"
  else
    # -f forces colour even though we're piping to a file; gives a stable gradient.
    figlet -f "$FONT" -w 120 "$txt" | lolcat -f -p 2
  fi
}

save() {  # $1 name  $2 text
  mkdir -p "$OUTDIR"
  local ext="ans"; [[ "$PLAIN" == true || "$HAS_LOLCAT" != true ]] && ext="txt"
  local f="$OUTDIR/$1.$ext"
  render "$2" > "$f"
  echo "  wrote $f"
}

if [[ -n "$TEXT" ]]; then
  render "$TEXT"
  save "$(echo "$TEXT" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')" "$TEXT"
  exit 0
fi

if [[ "$ALL" == true ]]; then
  echo "Generating themed banner set (font=$FONT, colour=$HAS_LOLCAT) -> $OUTDIR"
  save planet-express "PLANET EXPRESS"
  save good-news      "GOOD NEWS"
  save bite-my        "SHINY METAL"
  save world-tomorrow "TOMORROW"
  save bender         "BENDER"
  save new-new-york   "NEW NEW YORK"
  save momcorp        "MOMCORP"
  echo "Done. MOTD shuffle/daily mode will include these. Set art mode with:"
  echo "  hl-conf MOTD_ART=shuffle   (or edit ~/.config/homelab-shell.conf)"
  exit 0
fi

echo "Nothing to do. Try --all or --text \"WORD\". See --help."
