#!/usr/bin/env bash
# shell/themes/modern.sh — powerline-style segment bar (no Nerd Font required).
#
#   ⬡ user@hermes  ~/homelab  main*  4s ▶
#
# Uses reverse-video blocks with rounded  separators. The arrowheads are
# from the standard Powerline range (U+E0B0); if your font lacks them they
# render as a box — set HOMELAB_SHELL_SEP=ascii in ~/.config/homelab-shell.conf
# to fall back to plain ">" separators. The host segment is the character colour.

# Separator glyph (Powerline by default, ASCII fallback opt-in).
__HL_SEP="${HOMELAB_SHELL_SEP:-pl}"
if [[ "$__HL_SEP" == ascii ]]; then __HL_ARROW=""; __HL_ARROW_THIN="|"
else __HL_ARROW=$''; __HL_ARROW_THIN=$''; fi

hl_timer_enable

# bg/fg segment helpers (256-colour reverse blocks).
__hl_seg() { # $1 bg256 $2 fg256 $3 text
  printf '\[\033[48;5;%sm\033[38;5;%sm\] %s ' "$1" "$2" "$3"
}
__hl_sep() { # $1 from_bg $2 to_bg  (arrowhead coloured from->to)
  if [[ -n "$2" ]]; then printf '\[\033[48;5;%sm\033[38;5;%sm\]%s' "$2" "$1" "$__HL_ARROW"
  else printf '\[\033[49m\033[38;5;%sm\]%s\[\033[0m\]' "$1" "$__HL_ARROW"; fi
}

__hl_set_prompt() {
  local ec=$?

  # Segment palette (bg codes). Host segment uses the character colour.
  local host_bg="$FUT_C256" host_fg=232
  # Light character colours need dark text; pick by code range heuristically.
  case "$FUT_C256" in 51|75|213|220|245|153) host_fg=232 ;; *) host_fg=255 ;; esac
  local path_bg=238 path_fg=255
  local git_bg=240  git_fg=187
  local time_bg=236 time_fg=246
  local err_bg=160  err_fg=255

  local out=""
  # host segment
  out+="$(__hl_seg "$host_bg" "$host_fg" "$FUT_GLYPH \u@\h")"
  out+="$(__hl_sep "$host_bg" "$path_bg")"
  # path
  out+="$(__hl_seg "$path_bg" "$path_fg" "\w")"

  # git
  hl_git_split
  if [[ -n "$HL_GIT_BRANCH" ]]; then
    out+="$(__hl_sep "$path_bg" "$git_bg")"
    out+="$(__hl_seg "$git_bg" "$git_fg" "${HL_GIT_BRANCH}${HL_GIT_DIRTY}")"
    local tail_bg="$git_bg"
  else
    local tail_bg="$path_bg"
  fi

  # timing
  if [[ -n "${HL_LAST_DURATION:-}" ]]; then
    out+="$(__hl_sep "$tail_bg" "$time_bg")"
    out+="$(__hl_seg "$time_bg" "$time_fg" "$HL_LAST_DURATION")"
    tail_bg="$time_bg"
  fi

  # error segment
  if (( ec != 0 )); then
    out+="$(__hl_sep "$tail_bg" "$err_bg")"
    out+="$(__hl_seg "$err_bg" "$err_fg" "✗$ec")"
    tail_bg="$err_bg"
  fi

  out+="$(__hl_sep "$tail_bg" "")"   # closing arrow, reset
  PS1="${out} "
}
