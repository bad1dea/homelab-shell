#!/usr/bin/env bash
# shell/motd/motd.sh — the message-of-the-day, Futurama edition.
#
# Prints a per-host ANSI art portrait next to a compact header + in-character
# quote, then a system status block below. Called automatically on SSH login
# by shell-common.sh, or by hand via `hl motd`. Dependency-light: everything
# degrades if a tool is missing (docker/zerotier optional; no figlet/lolcat
# required).
#
# Flags:
#   --art-only     just the portrait
#   --quote-only   just the quote
#   --no-art       skip the portrait (status + quote only)
#   --plain        no colour (for logs / dumb terminals)
#
# Art selection (config key MOTD_ART in ~/.config/homelab-shell.conf, or env
# HOMELAB_MOTD_ART):
#   host    (default) the character art for THIS host, else the default banner
#   shuffle a random piece every login
#   daily   a piece that changes once per day (stable within the day)
#   off     no art

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$(cd "$DIR/../lib" && pwd)"
# shellcheck source=../lib/futurama.sh
source "$LIB/futurama.sh"
fut_persona

ART_ONLY=false; QUOTE_ONLY=false; NO_ART=false; PLAIN=false; HOST_OVERRIDE=""
for a in "$@"; do case "$a" in
  --art-only) ART_ONLY=true ;;
  --quote-only) QUOTE_ONLY=true ;;
  --no-art) NO_ART=true ;;
  --plain) PLAIN=true ;;
  --*) ;;
  *) HOST_OVERRIDE="$a" ;;   # preview a specific host's persona
esac; done
[[ -n "$HOST_OVERRIDE" ]] && fut_persona "$HOST_OVERRIDE"

# Colour helpers (respect --plain and non-tty).
if $PLAIN || { [[ ! -t 1 ]] && [[ -z "${HOMELAB_MOTD_FORCE_COLOR:-}" ]]; }; then
  HCOL=""; DIM=""; RST=""
else
  HCOL="$(fut_fg "$FUT_C256" "$FUT_C16")"
  DIM="$(fut_fg 245 90)"; RST="$(fut_reset)"
fi

# Read MOTD_ART preference.
ART_MODE="${HOMELAB_MOTD_ART:-host}"
CONF="${HOMELAB_SHELL_CONF:-$HOME/.config/homelab-shell.conf}"
if [[ -z "${HOMELAB_MOTD_ART:-}" && -f "$CONF" ]]; then
  v="$(grep -E '^MOTD_ART=' "$CONF" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' "')"
  [[ -n "$v" ]] && ART_MODE="$v"
fi

# The portraits in art/portraits/*.png are all pre-cropped to square, so a
# fixed chafa --size renders EVERY character at the identical 36x19 cell grid
# — required for the side-by-side art+text layout below. The pre-rendered
# art/*.ans files (render-portraits.sh) were generated at the same size, so
# the chafa-less fallback lines up too.
MAX_ART_WIDTH=36

# Shrink the art (live chafa render only — the .ans fallback is fixed at
# 36x18, see load_art) so art + gap + text fits the actual terminal. Without
# this, a narrow SSH terminal (e.g. 80 cols) wraps each combined line and the
# text ends up below the portrait instead of beside it.
COLS="${COLUMNS:-}"
[[ -z "$COLS" ]] && COLS="$(tput cols 2>/dev/null)"
[[ -z "$COLS" || "$COLS" -lt 1 ]] && COLS=80
GAP=2
MIN_TEXT_WIDTH=24
ART_WIDTH=$(( COLS - GAP - 40 ))
(( ART_WIDTH > MAX_ART_WIDTH )) && ART_WIDTH=$MAX_ART_WIDTH
(( ART_WIDTH < 16 )) && ART_WIDTH=16
ART_HEIGHT=$(( ART_WIDTH / 2 ))

# Echo one of the given paths that actually exists. daily mode = stable per day
# (same pick all day); otherwise random — i.e. a fresh variant every login.
pick_one() {  # $@ = candidate paths (globs ok; non-matches are filtered)
  local real=() f
  for f in "$@"; do [[ -f "$f" ]] && real+=("$f"); done
  [[ ${#real[@]} -gt 0 ]] || return 1
  local idx
  if [[ "$ART_MODE" == daily ]]; then idx=$(( 10#$(date +%j) % ${#real[@]} ))
  else idx=$(( RANDOM % ${#real[@]} )); fi
  printf '%s\n' "${real[$idx]}"
}

# Fallback chooser (no chafa / no PNG): a random .ans, then the default banner.
pick_art() {
  local artdir="$DIR/art"
  case "$ART_MODE" in
    off) return 1 ;;
    host)          pick_one "$artdir/$FUT_HOST"-*.ans && return 0 ;;
    shuffle|daily) pick_one "$artdir"/*.ans "$artdir"/*.txt && return 0 ;;
  esac
  [[ -f "$artdir/planet-express.txt" ]] && { echo "$artdir/planet-express.txt"; return 0; }
  return 1
}

# Render a character PNG live, adapting to the terminal's colour depth.
# Returns non-zero (and prints nothing) if chafa is missing/too old/errors, so
# the caller can fall back to the pre-rendered .ans. NB: --align is chafa 1.14+,
# so it's deliberately not used here (Debian 12 ships 1.12).
chafa_render() {  # $1 = png path
  local depth="${HOMELAB_MOTD_COLORS:-full}" out
  out="$(chafa --format symbols --symbols vhalf+space -c "$depth" \
               --size "${ART_WIDTH}x${ART_HEIGHT}" "$1" 2>/dev/null)" || return 1
  [[ -n "$out" ]] || return 1
  printf '%s\n' "$out"
}

# Populate ART_RAW with the chosen art's raw (possibly ANSI-coloured) text, or
# leave it empty if ART_MODE=off / nothing is available. ART_IS_PORTRAIT=true
# when the result is one of the 24x13 portrait grids (so the caller can lay it
# out side-by-side with text); false for the rare wide-banner fallback.
load_art() {
  ART_RAW=""; ART_IS_PORTRAIT=false
  [[ "$ART_MODE" == off ]] && return 0

  local pool=()
  case "$ART_MODE" in
    host)          pool=( "$DIR/art/portraits/$FUT_HOST"-*.png ) ;;
    shuffle|daily) pool=( "$DIR/art/portraits/"*.png ) ;;
  esac
  local png; png="$(pick_one "${pool[@]}" 2>/dev/null)" || png=""
  if [[ -n "$png" ]]; then
    if command -v chafa >/dev/null 2>&1; then ART_RAW="$(chafa_render "$png")" || ART_RAW=""; fi
    if [[ -z "$ART_RAW" ]]; then
      local ans="$DIR/art/$(basename "$png" .png).ans"
      # .ans files are pre-rendered at the fixed 36x18 size, not the
      # terminal-adapted ART_WIDTH/ART_HEIGHT — line layout below must match.
      if [[ -f "$ans" ]]; then ART_RAW="$(cat "$ans")"; ART_WIDTH=36; ART_HEIGHT=18; fi
    fi
    [[ -n "$ART_RAW" ]] && { ART_IS_PORTRAIT=true; ART_RAW="${ART_RAW//$'\033[?25l'/}"; return 0; }
  fi

  local f; f="$(pick_art)" || return 0
  if [[ "$f" == *.ans ]]; then
    ART_RAW="$(cat "$f")"
    ART_RAW="${ART_RAW//$'\033[?25l'/}"
  elif command -v lolcat >/dev/null 2>&1 && [[ "${HOMELAB_MOTD_LOLCAT:-}" == 1 ]]; then
    ART_RAW="$(lolcat -f < "$f")"
  else
    ART_RAW="$(printf '%s' "$HCOL"; cat "$f"; printf '%s' "$RST")"
  fi
}

print_art() {
  load_art
  [[ -n "$ART_RAW" ]] || return 0
  echo
  printf '%s\n' "$ART_RAW"
  echo
}

# ── quote ─────────────────────────────────────────────────────────────────────
pick_quote() {
  local qf="$DIR/quotes.txt"
  [[ -r "$qf" ]] || return 0
  # lines tagged with this character OR "any"
  local lines; mapfile -t lines < <(grep -vE '^\s*#|^\s*$' "$qf" | grep -E "^(${FUT_QUOTEKEY}|any)\|")
  [[ ${#lines[@]} -gt 0 ]] || mapfile -t lines < <(grep -vE '^\s*#|^\s*$' "$qf" | grep -E '^any\|')
  [[ ${#lines[@]} -gt 0 ]] || return 0
  local pick="${lines[$(( RANDOM % ${#lines[@]} ))]}"
  printf '%s\n' "${pick#*|}"
}

random_quote() {
  local q; q="$(pick_quote)"
  [[ -n "$q" ]] && printf '\n%s“%s”%s\n' "$HCOL" "$q" "$RST"
}

# ── art + header + quote, side by side ──────────────────────────────────────
print_banner() {
  load_art
  local now; now="$(date '+%a %Y-%m-%d %H:%M %Z')"

  # Text column width: whatever's left after the art + gap, but not so
  # narrow it's unreadable — fall back to the old stacked layout below that.
  local text_width=$(( COLS - ART_WIDTH - GAP ))
  local side_by_side=true
  (( text_width < MIN_TEXT_WIDTH )) && side_by_side=false
  (( text_width > 56 )) && text_width=56

  local text=()
  text+=("$HCOL$FUT_GLYPH$RST  $HCOL$FUT_HOST$RST  $DIM—$RST  $FUT_NAME")
  text+=("$DIM$FUT_TAG  ·  $now$RST")
  local q; q="$(pick_quote)"
  if [[ -n "$q" ]]; then
    text+=("")
    local wrapped; mapfile -t wrapped < <(fold -s -w "$text_width" <<< "$q")
    local last=$(( ${#wrapped[@]} - 1 )) i
    for i in "${!wrapped[@]}"; do
      local l="${wrapped[$i]}"
      [[ $i -eq 0 ]] && l="“$l"
      [[ $i -eq $last ]] && l="$l”"
      text+=("$HCOL$l$RST")
    done
  fi

  if [[ "$ART_IS_PORTRAIT" != true || "$side_by_side" != true ]]; then
    # No portrait, or the terminal's too narrow for side-by-side: old
    # stacked layout (art above, text below).
    [[ -n "$ART_RAW" ]] && { echo; printf '%s\n' "$ART_RAW"; }
    echo
    local line; for line in "${text[@]}"; do printf '%s\n' "$line"; done
    return 0
  fi

  local art_lines=()
  [[ -n "$ART_RAW" ]] && mapfile -t art_lines <<< "$ART_RAW"
  local pad; pad="$(printf '%*s' "$ART_WIDTH" '')"

  # Vertically centre the (shorter) text block alongside the portrait.
  local n=${#art_lines[@]} m=${#text[@]}
  local offset=0; (( n > m )) && offset=$(( (n - m) / 2 ))
  local total=$(( n > m ? n : m )) i
  echo
  for (( i=0; i<total; i++ )); do
    local t=""; local ti=$(( i - offset ))
    (( ti >= 0 && ti < m )) && t="${text[$ti]}"
    printf '%s  %s\n' "${art_lines[$i]:-$pad}" "$t"
  done
  echo
}

# ── system status ────────────────────────────────────────────────────────────
kv() { printf '  %s%-9s%s %s\n' "$DIM" "$1" "$RST" "$2"; }

collect_status() {
  # OS / kernel
  local os="unknown"
  [[ -r /etc/os-release ]] && os="$(. /etc/os-release; echo "$PRETTY_NAME")"
  kv "os" "$os ($(uname -r))"

  # uptime + load
  local up load
  up="$(uptime -p 2>/dev/null | sed 's/^up //')"; [[ -z "$up" ]] && up="$(uptime 2>/dev/null)"
  load="$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"
  kv "uptime" "${up:-?}   ${DIM}load${RST} ${load:-?}"

  # memory
  if [[ -r /proc/meminfo ]]; then
    local mt ma used pct
    mt=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    ma=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
    if [[ -n "$mt" && -n "$ma" ]]; then
      used=$(( (mt-ma)/1024 )); mt=$(( mt/1024 )); pct=$(( used*100/(mt>0?mt:1) ))
      kv "memory" "${used}/${mt} MiB (${pct}%)"
    fi
  fi

  # disk — root, plus the first data/storage mount that exists
  local m
  for m in / /data /mnt/storage /srv /mnt/user; do
    [[ "$m" == "/" || -d "$m" ]] || continue
    mountpoint -q "$m" 2>/dev/null || [[ "$m" == "/" ]] || continue
    local row
    row=$(df -h --output=used,size,pcent "$m" 2>/dev/null | tail -1)
    [[ -n "$row" ]] && kv "disk" "$(echo "$row" | awk '{printf "%s used of %s (%s)", $1,$2,$3}')  ${DIM}${m}${RST}"
    [[ "$m" != "/" ]] && break   # root + one data mount is enough
  done

  # IP addresses (prefer the ZeroTier 10.99 if present)
  local ips zt
  ips="$(hostname -I 2>/dev/null)"
  zt="$(echo "$ips" | tr ' ' '\n' | grep -E '^10\.99\.' | head -1)"
  [[ -n "$zt" ]] && kv "zerotier" "$zt" || kv "ip" "$(echo "$ips" | awk '{print $1}')"

  # docker
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    local run tot
    run=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    tot=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
    local unhealthy
    unhealthy=$(docker ps --filter health=unhealthy -q 2>/dev/null | wc -l | tr -d ' ')
    local extra=""; [[ "$unhealthy" -gt 0 ]] && extra="  $(fut_fg 203 31)⚠ ${unhealthy} unhealthy$RST"
    kv "docker" "${run}/${tot} containers up${extra}"
  fi

  # failed systemd units (servers care about this)
  if command -v systemctl >/dev/null 2>&1; then
    local failed
    failed=$(systemctl --failed --no-legend 2>/dev/null | wc -l | tr -d ' ')
    [[ "$failed" -gt 0 ]] && kv "systemd" "$(fut_fg 203 31)${failed} failed unit(s)$RST"
  fi

  # logged-in users besides us
  local who; who=$(who 2>/dev/null | wc -l | tr -d ' ')
  [[ "$who" -gt 1 ]] && kv "sessions" "$who users logged in"

  # pending repo commits (is the host behind the source of truth?)
  if [[ -f /etc/default/homelab ]]; then
    local rd; rd="$(. /etc/default/homelab 2>/dev/null; echo "${REPO_DIR:-}")"
    if [[ -n "$rd" && -d "$rd/.git" ]]; then
      local behind
      behind=$(git -C "$rd" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
      [[ "$behind" -gt 0 ]] && kv "repo" "$(fut_fg 215 33)${behind} commit(s) behind — run sync-hosts$RST"
    fi
  fi
}

rule() { printf '%s%s%s\n' "$DIM" "────────────────────────────────────────────────────────" "$RST"; }

# ── compose output ───────────────────────────────────────────────────────────
if $ART_ONLY; then print_art; exit 0; fi
if $QUOTE_ONLY; then random_quote; exit 0; fi

if $NO_ART; then
  printf '%s %s%s%s  —  %s%s%s\n' \
    "$HCOL$FUT_GLYPH$RST" "$HCOL" "$FUT_HOST" "$RST" "$DIM" "$FUT_NAME" "$RST"
  printf '%s%s · %s%s\n' "$DIM" "$FUT_TAG" "$(date '+%a %Y-%m-%d %H:%M %Z')" "$RST"
  random_quote
else
  print_banner
fi
rule
collect_status
echo
