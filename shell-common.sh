#!/usr/bin/env bash
# shell/shell-common.sh
#
# THE one line you add to ~/.bashrc:
#     source /path/to/homelab/shell/shell-common.sh
# (install.sh does this for you; deploy-shell.sh does it across the fleet.)
#
# Everything downstream — which prompt theme, the MOTD, per-host colour — is
# resolved from here at shell start, reading the repo's shell/ dir. So once the
# bashrc line exists, a `git pull` (which the fleet already does) is the ONLY
# thing needed to roll out a new prompt or a new piece of MOTD art. No re-deploy.
#
# Config (lowest → highest priority):
#   1. defaults below
#   2. ~/.config/homelab-shell.conf   (THEME=..., MOTD=..., written by install.sh)
#   3. environment ($HOMELAB_SHELL_THEME, $HOMELAB_SHELL_MOTD)
#
# THEME : simple | fancy | modern | minimal | classic | starship   (default fancy)
# MOTD  : auto (on SSH login only) | always | off                  (default auto)

# Resolve our own location even when sourced.
HOMELAB_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HOMELAB_SHELL_DIR

# Only meaningful in interactive shells. Non-interactive (scp, git, cron) bail
# now — but AFTER exporting the dir, so tooling can still find the MOTD script.
case $- in *i*) : ;; *) return 0 2>/dev/null || exit 0 ;; esac

# ── load the libraries + persona ─────────────────────────────────────────────
# shellcheck source=lib/futurama.sh
source "$HOMELAB_SHELL_DIR/lib/futurama.sh"
# shellcheck source=lib/prompt-common.sh
source "$HOMELAB_SHELL_DIR/lib/prompt-common.sh"
fut_persona            # populate FUT_* for this host
export HL_HOST_GLYPH="$FUT_GLYPH" HL_HOST_NAME="$FUT_NAME"

# ── resolve config ───────────────────────────────────────────────────────────
HOMELAB_SHELL_CONF="${HOMELAB_SHELL_CONF:-$HOME/.config/homelab-shell.conf}"
__HL_THEME="fancy"; __HL_MOTD="auto"
if [[ -f "$HOMELAB_SHELL_CONF" ]]; then
  # Only accept the keys we know, so a stray file can't run arbitrary code.
  while IFS='=' read -r k v; do
    k="${k// /}"; v="${v%%#*}"; v="${v//\"/}"; v="${v// /}"
    case "$k" in
      THEME) __HL_THEME="$v" ;;
      MOTD)  __HL_MOTD="$v" ;;
      SEP)   export HOMELAB_SHELL_SEP="$v" ;;
    esac
  done < "$HOMELAB_SHELL_CONF"
fi
__HL_THEME="${HOMELAB_SHELL_THEME:-$__HL_THEME}"
__HL_MOTD="${HOMELAB_SHELL_MOTD:-$__HL_MOTD}"

# ── apply the prompt ─────────────────────────────────────────────────────────
__hl_apply_theme() {
  local theme="$1"
  if [[ "$theme" == starship ]]; then
    if command -v starship >/dev/null 2>&1; then
      export STARSHIP_CONFIG="$HOMELAB_SHELL_DIR/themes/starship.toml"
      # Clear any bash-theme render hook so the two engines don't fight.
      PROMPT_COMMAND="${PROMPT_COMMAND//__hl_set_prompt/}"
      eval "$(starship init bash)"
      return 0
    fi
    echo "homelab-shell: starship not installed — falling back to 'fancy'." >&2
    theme="fancy"
  fi
  local f="$HOMELAB_SHELL_DIR/themes/${theme}.sh"
  if [[ ! -r "$f" ]]; then
    echo "homelab-shell: unknown theme '$theme' — using 'fancy'." >&2
    f="$HOMELAB_SHELL_DIR/themes/fancy.sh"
  fi
  # Coming from starship? Drop its hook + config so the engines don't both run.
  PROMPT_COMMAND="${PROMPT_COMMAND//starship_precmd/}"
  unset STARSHIP_CONFIG STARSHIP_SHELL 2>/dev/null || true
  # shellcheck source=/dev/null
  source "$f"     # defines __hl_set_prompt (and may enable timing)
  case ";${PROMPT_COMMAND:-};" in
    *";__hl_set_prompt;"*|*"__hl_set_prompt;"*|*";__hl_set_prompt"*) : ;;
    *) PROMPT_COMMAND="__hl_set_prompt;${PROMPT_COMMAND:-}" ;;
  esac
}
__hl_apply_theme "$__HL_THEME"

# ── MOTD on login ────────────────────────────────────────────────────────────
# Show once per login shell. "auto" = only over SSH (so local terminals aren't
# spammed every tab); "always" = every interactive login; "off" = never.
__hl_maybe_motd() {
  [[ -z "${HOMELAB_MOTD_SHOWN:-}" ]] || return 0
  case "$__HL_MOTD" in
    off)    return 0 ;;
    always) : ;;
    auto)   hl_is_ssh || return 0 ;;
    *)      return 0 ;;
  esac
  # Only on login shells (the first shell of the SSH session), not every subshell.
  shopt -q login_shell || [[ -n "${SSH_TTY:-}" ]] || return 0
  export HOMELAB_MOTD_SHOWN=1
  "$HOMELAB_SHELL_DIR/motd/motd.sh" 2>/dev/null || true
}
__hl_maybe_motd

# ── in-shell management: `hl <cmd>` ──────────────────────────────────────────
# Live theme switching has to be a shell function (a subprocess can't change the
# current shell's PS1). Writes the conf and re-sources so the change is instant.
hl() {
  local cmd="${1:-help}"; shift || true
  case "$cmd" in
    theme)
      local t="${1:-}"
      if [[ -z "$t" ]]; then echo "current theme: $__HL_THEME"; return 0; fi
      mkdir -p "$(dirname "$HOMELAB_SHELL_CONF")"
      if grep -q '^THEME=' "$HOMELAB_SHELL_CONF" 2>/dev/null; then
        sed -i "s/^THEME=.*/THEME=$t/" "$HOMELAB_SHELL_CONF"
      else
        echo "THEME=$t" >> "$HOMELAB_SHELL_CONF"
      fi
      HOMELAB_SHELL_THEME="$t" source "$HOMELAB_SHELL_DIR/shell-common.sh"
      echo "switched to '$t'." ;;
    list|themes)
      echo "available themes:"
      for f in "$HOMELAB_SHELL_DIR"/themes/*.sh; do
        local n; n="$(basename "$f" .sh)"
        [[ "$n" == "$__HL_THEME" ]] && printf '  * %s (current)\n' "$n" || printf '    %s\n' "$n"
      done
      command -v starship >/dev/null && echo "    starship (engine)" ;;
    motd)    HOMELAB_MOTD_SHOWN="" "$HOMELAB_SHELL_DIR/motd/motd.sh" ;;
    art)     "$HOMELAB_SHELL_DIR/motd/motd.sh" --art-only ;;
    quote)   "$HOMELAB_SHELL_DIR/motd/motd.sh" --quote-only ;;
    who)     echo "$FUT_GLYPH  $FUT_HOST is $FUT_NAME — \"$FUT_TAG\"" ;;
    reload)  source "$HOMELAB_SHELL_DIR/shell-common.sh"; echo "reloaded." ;;
    help|*)
      cat <<EOF
hl — homelab shell control ($FUT_HOST = $FUT_NAME)
  hl theme [name]   switch prompt theme live (no arg = show current)
  hl list           list available themes
  hl motd           reprint the full message-of-the-day
  hl art            just the ANSI art banner
  hl quote          a random in-character quote
  hl who            which character is this host
  hl reload         re-source after a git pull
EOF
      ;;
  esac
}
