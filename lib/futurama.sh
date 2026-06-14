#!/usr/bin/env bash
# shell/lib/futurama.sh
#
# The fleet is named after Futurama characters, so the prompt + MOTD lean into
# it: every host gets its character's signature COLOR, a GLYPH, and a stash of
# in-character one-liners. This is the single source of truth for "what does
# host X look/sound like" — themes and the MOTD both source it.
#
# Public API (after sourcing):
#   fut_persona [host]   -> populates the FUT_* globals for that host (default:
#                           short hostname). Unknown hosts get a deterministic
#                           color + a generic New-New-York persona.
#   fut_supports_256     -> 0 if the terminal can do 256 colours
#   fut_fg <256> <basic> -> raw SGR escape (256 if supported, else basic)
#   fut_fg_p <256> <basic> -> same, wrapped in \[ \] for use inside PS1
#   fut_reset / fut_reset_p
#
# Globals set by fut_persona:
#   FUT_HOST     short hostname keyed on
#   FUT_NAME     character's full name
#   FUT_GLYPH    a single-rune sigil for the prompt/banner
#   FUT_C256     256-colour code (foreground)
#   FUT_C16      basic 16-colour fallback code
#   FUT_QUOTEKEY which quote bucket to draw from (motd/quotes.txt tags)
#   FUT_TAG      one-word vibe used in the MOTD subtitle

# ── terminal capability ──────────────────────────────────────────────────────
fut_supports_256() {
  case "${COLORTERM:-}" in *truecolor*|*24bit*) return 0 ;; esac
  case "${TERM:-}" in *256color*) return 0 ;; esac
  local n; n=$(tput colors 2>/dev/null || echo 0)
  [[ "$n" -ge 256 ]]
}

# raw foreground escape. $1 = 256 code, $2 = basic (30-37 / 90-97) fallback.
fut_fg() {
  if fut_supports_256; then printf '\033[38;5;%sm' "$1"
  else printf '\033[%sm' "$2"; fi
}
fut_reset() { printf '\033[0m'; }

# PS1-safe variants: wrap non-printing bytes in \[ \] so bash counts the line
# length correctly (otherwise long commands wrap wrong).
fut_fg_p()  { printf '\[%s\]' "$(fut_fg "$1" "$2")"; }
fut_reset_p() { printf '\[\033[0m\]'; }

# ── the character table ──────────────────────────────────────────────────────
# Keyed on short hostname. Fields: name | glyph | c256 | c16 | quotekey | tag
fut_persona() {
  local host="${1:-$(hostname -s 2>/dev/null || echo unknown)}"
  host="${host,,}"
  FUT_HOST="$host"
  case "$host" in
    hermes)
      FUT_NAME="Hermes Conrad"; FUT_GLYPH="⬡"; FUT_C256=35;  FUT_C16=32
      FUT_QUOTEKEY=hermes;    FUT_TAG="bureaucracy, grade-3" ;;
    bender)
      FUT_NAME="Bender Bending Rodríguez"; FUT_GLYPH="▓"; FUT_C256=51; FUT_C16=36
      FUT_QUOTEKEY=bender;    FUT_TAG="shiny metal" ;;
    leela)
      FUT_NAME="Turanga Leela"; FUT_GLYPH="◉"; FUT_C256=99; FUT_C16=35
      FUT_QUOTEKEY=leela;     FUT_TAG="one eye on everything" ;;
    fry)
      FUT_NAME="Philip J. Fry"; FUT_GLYPH="◔"; FUT_C256=208; FUT_C16=33
      FUT_QUOTEKEY=fry;       FUT_TAG="delivery boy" ;;
    amy)
      FUT_NAME="Amy Wong"; FUT_GLYPH="✿"; FUT_C256=213; FUT_C16=95
      FUT_QUOTEKEY=amy;       FUT_TAG="spluh" ;;
    nibbler)
      FUT_NAME="Lord Nibbler"; FUT_GLYPH="◖"; FUT_C256=245; FUT_C16=90
      FUT_QUOTEKEY=nibbler;   FUT_TAG="dark matter" ;;
    professor)
      FUT_NAME="Professor Farnsworth"; FUT_GLYPH="⚗"; FUT_C256=75; FUT_C16=34
      FUT_QUOTEKEY=professor; FUT_TAG="good news, everyone" ;;
    url)
      FUT_NAME="URL"; FUT_GLYPH="✦"; FUT_C256=33; FUT_C16=34
      FUT_QUOTEKEY=url;       FUT_TAG="the law" ;;
    mom)
      FUT_NAME="Mom"; FUT_GLYPH="✸"; FUT_C256=196; FUT_C16=31
      FUT_QUOTEKEY=mom;       FUT_TAG="MomCorp" ;;
    zoidberg)
      FUT_NAME="Dr. John Zoidberg"; FUT_GLYPH="◣"; FUT_C256=173; FUT_C16=31
      FUT_QUOTEKEY=default;   FUT_TAG="hooray" ;;
    zapp)
      FUT_NAME="Zapp Brannigan"; FUT_GLYPH="★"; FUT_C256=220; FUT_C16=33
      FUT_QUOTEKEY=default;   FUT_TAG="velour" ;;
    kif)
      FUT_NAME="Kif Kroker"; FUT_GLYPH="≈"; FUT_C256=79; FUT_C16=32
      FUT_QUOTEKEY=default;   FUT_TAG="*sigh*" ;;
    scruffy)
      FUT_NAME="Scruffy"; FUT_GLYPH="¶"; FUT_C256=130; FUT_C16=33
      FUT_QUOTEKEY=default;   FUT_TAG="the janitor" ;;
    calculon)
      FUT_NAME="Calculon"; FUT_GLYPH="◈"; FUT_C256=141; FUT_C16=35
      FUT_QUOTEKEY=default;   FUT_TAG="acting!" ;;
    morbo)
      FUT_NAME="Morbo"; FUT_GLYPH="☢"; FUT_C256=46; FUT_C16=32
      FUT_QUOTEKEY=default;   FUT_TAG="watch the skies" ;;
    linda)
      FUT_NAME="Linda van Schoonhoven"; FUT_GLYPH="◍"; FUT_C256=223; FUT_C16=33
      FUT_QUOTEKEY=default;   FUT_TAG="...back to you" ;;
    nixon)
      FUT_NAME="Richard Nixon's Head"; FUT_GLYPH="❖"; FUT_C256=30; FUT_C16=36
      FUT_QUOTEKEY=default;   FUT_TAG="Arooo!" ;;
    cubert)
      FUT_NAME="Cubert Farnsworth"; FUT_GLYPH="◇"; FUT_C256=75; FUT_C16=34
      FUT_QUOTEKEY=default;   FUT_TAG="that's scientifically impossible" ;;
    robotdevil|robot-devil)
      FUT_NAME="The Robot Devil"; FUT_GLYPH="♆"; FUT_C256=196; FUT_C16=31
      FUT_QUOTEKEY=default;   FUT_TAG="a deal's a deal" ;;
    *)
      # Unknown host: deterministic colour from the name so it's at least stable,
      # plus a generic New-New-York persona.
      local palette256=(208 99 51 35 213 75 220 79 141 173)
      local palette16=(33 35 36 32 95 34 33 32 35 31)
      local sum=0 i ch
      for (( i=0; i<${#host}; i++ )); do
        printf -v ch '%d' "'${host:$i:1}"; sum=$(( (sum + ch) % 10 ))
      done
      FUT_NAME="${host^}"; FUT_GLYPH="◆"
      FUT_C256=${palette256[$sum]}; FUT_C16=${palette16[$sum]}
      FUT_QUOTEKEY=default; FUT_TAG="new new york" ;;
  esac
}
