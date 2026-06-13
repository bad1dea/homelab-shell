#!/usr/bin/env bash
# shell/motd/motd.sh — the message-of-the-day, Futurama edition.
#
# Prints a per-host ANSI art banner, a compact system status block, and a random
# in-character quote. Called automatically on SSH login by shell-common.sh, or
# by hand via `hl motd`. Dependency-light: everything degrades if a tool is
# missing (docker/zerotier optional; no figlet/lolcat required).
#
# Flags:
#   --art-only     just the banner
#   --quote-only   just the quote
#   --no-art       skip the banner (status + quote only)
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

pick_art() {
  local artdir="$DIR/art"
  case "$ART_MODE" in
    off) return 1 ;;
    host)
      # Prefer a pre-rendered colour portrait (.ans), then hand-drawn (.txt),
      # then the default banner. (Live chafa render is handled in print_art.)
      local ext
      for ext in ans txt; do
        [[ -f "$artdir/$FUT_HOST.$ext" ]] && { echo "$artdir/$FUT_HOST.$ext"; return 0; }
      done
      [[ -f "$artdir/planet-express.txt" ]] && { echo "$artdir/planet-express.txt"; return 0; }
      return 1 ;;
    shuffle|daily)
      local files=( "$artdir"/*.txt "$artdir"/*.ans )
      local real=(); local f; for f in "${files[@]}"; do [[ -f "$f" ]] && real+=("$f"); done
      [[ ${#real[@]} -gt 0 ]] || return 1
      local idx
      if [[ "$ART_MODE" == daily ]]; then
        idx=$(( $(date +%j) % ${#real[@]} ))
      else
        idx=$(( RANDOM % ${#real[@]} ))
      fi
      echo "${real[$idx]}"; return 0 ;;
  esac
  return 1
}

# Render a character PNG live, adapting to the terminal's colour depth + size.
chafa_render() {  # $1 = png path
  local depth="${HOMELAB_MOTD_COLORS:-full}" w="${HOMELAB_MOTD_ART_WIDTH:-32}"
  chafa --format symbols --symbols vhalf+space -c "$depth" \
        --size "${w}x26" --align top,left "$1" 2>/dev/null
}

print_art() {
  [[ "$ART_MODE" == off ]] && return 0
  echo
  # Best quality: live, terminal-adaptive portrait when chafa + a PNG are present
  # (host mode only). Everywhere else, fall back to a pre-rendered file.
  if [[ "$ART_MODE" == host ]] && command -v chafa >/dev/null 2>&1; then
    local png="$DIR/art/portraits/$FUT_HOST.png"
    if [[ -f "$png" ]]; then chafa_render "$png"; echo; return 0; fi
  fi
  local f; f="$(pick_art)" || return 0
  if [[ "$f" == *.ans ]]; then
    cat "$f"                                   # pre-coloured: print raw
  elif command -v lolcat >/dev/null 2>&1 && [[ "${HOMELAB_MOTD_LOLCAT:-}" == 1 ]]; then
    lolcat -f "$f"                             # ASCII art, rainbow
  else
    printf '%s' "$HCOL"; cat "$f"; printf '%s' "$RST"   # ASCII art, character tint
  fi
  echo
}

print_header() {
  local now; now="$(date '+%a %Y-%m-%d %H:%M %Z')"
  printf '%s %s%s%s  —  %s%s%s\n' \
    "$HCOL$FUT_GLYPH$RST" "$HCOL" "$FUT_HOST" "$RST" "$DIM" "$FUT_NAME" "$RST"
  printf '%s%s · %s%s\n' "$DIM" "$FUT_TAG" "$now" "$RST"
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

random_quote() {
  local qf="$DIR/quotes.txt"
  [[ -r "$qf" ]] || return 0
  # lines tagged with this character OR "any"
  local lines; mapfile -t lines < <(grep -vE '^\s*#|^\s*$' "$qf" | grep -E "^(${FUT_QUOTEKEY}|any)\|")
  [[ ${#lines[@]} -gt 0 ]] || mapfile -t lines < <(grep -vE '^\s*#|^\s*$' "$qf" | grep -E '^any\|')
  [[ ${#lines[@]} -gt 0 ]] || return 0
  local pick="${lines[$(( RANDOM % ${#lines[@]} ))]}"
  printf '\n%s“%s”%s\n' "$HCOL" "${pick#*|}" "$RST"
}

rule() { printf '%s%s%s\n' "$DIM" "────────────────────────────────────────────────────────" "$RST"; }

# ── compose output ───────────────────────────────────────────────────────────
if $ART_ONLY; then print_art; exit 0; fi
if $QUOTE_ONLY; then random_quote; exit 0; fi

$NO_ART || print_art
print_header
rule
collect_status
random_quote
echo
