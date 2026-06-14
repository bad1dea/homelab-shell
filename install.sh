#!/usr/bin/env bash
# shell/install.sh — wire the homelab shell (prompt + MOTD) into THIS account.
#
# What it does (idempotent, safe to re-run):
#   1. drops a single sourced line into ~/.bashrc pointing at shell-common.sh
#   2. writes ~/.config/homelab-shell.conf with your chosen theme / MOTD mode
#   3. symlinks the bin/ helpers (prompt-preview, motd) into ~/.local/bin
#   4. (optional) installs starship / figlet / lolcat if you ask for them
#
# It does NOT need root. Run it as the user whose shell you want themed (on a
# server: your login user AND/OR root, run once each). The prompt/MOTD then
# track the repo — a `git pull` is all that's needed to update afterwards.
#
# Usage:
#   shell/install.sh                       # theme=fancy, motd=auto
#   shell/install.sh --theme modern        # pick a theme
#   shell/install.sh --motd always         # MOTD on every login, not just SSH
#   shell/install.sh --art shuffle         # randomise the banner each login
#   shell/install.sh --with-starship       # also install the starship binary
#   shell/install.sh --with-fonts          # figlet + lolcat for the art generator
#   shell/install.sh --uninstall           # remove the bashrc hook

set -euo pipefail
SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON="$SHELL_DIR/shell-common.sh"

THEME="fancy"; MOTD="auto"; ART="host"; WITH_STARSHIP=false; WITH_FONTS=false; UNINSTALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme) THEME="$2"; shift 2 ;;
    --motd)  MOTD="$2";  shift 2 ;;
    --art)   ART="$2";   shift 2 ;;
    --with-starship) WITH_STARSHIP=true; shift ;;
    --with-fonts)    WITH_FONTS=true; shift ;;
    --uninstall)     UNINSTALL=true; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

BASHRC="$HOME/.bashrc"
MARK_BEGIN="# >>> homelab-shell >>>"
MARK_END="# <<< homelab-shell <<<"

strip_block() {  # remove an existing managed block from ~/.bashrc
  [[ -f "$BASHRC" ]] || return 0
  if grep -qF "$MARK_BEGIN" "$BASHRC"; then
    sed -i "/$(printf '%s' "$MARK_BEGIN" | sed 's/[][\.*^$/]/\\&/g')/,/$(printf '%s' "$MARK_END" | sed 's/[][\.*^$/]/\\&/g')/d" "$BASHRC"
  fi
}

if $UNINSTALL; then
  strip_block
  echo "removed homelab-shell block from $BASHRC (conf + repo left in place)."
  exit 0
fi

# ── 1. bashrc hook ───────────────────────────────────────────────────────────
touch "$BASHRC"
strip_block
{
  echo "$MARK_BEGIN"
  echo "# Managed by homelab shell/install.sh — edit theme via 'hl theme <name>'"
  echo "[ -r \"$COMMON\" ] && source \"$COMMON\""
  echo "$MARK_END"
} >> "$BASHRC"
echo "✔ hooked $BASHRC -> $COMMON"

# Suppress the login "Last login: ..." / mail notice lines (user-level; honoured
# by pam_lastlog). The distro /etc/motd banner needs root — deploy-shell.sh
# handles that fleet-wide.
touch "$HOME/.hushlogin"

# ── 2. config ────────────────────────────────────────────────────────────────
CONF="$HOME/.config/homelab-shell.conf"
mkdir -p "$(dirname "$CONF")"
cat > "$CONF" <<EOF
# homelab shell config — edit freely, or use 'hl theme <name>'.
# THEME: simple | fancy | modern | minimal | classic | starship
THEME=$THEME
# MOTD: auto (SSH only) | always | off
MOTD=$MOTD
# MOTD_ART: host | shuffle | daily | off
MOTD_ART=$ART
# SEP: pl (Powerline) | ascii  — only affects the 'modern' theme
SEP=pl
EOF
echo "✔ wrote $CONF (theme=$THEME motd=$MOTD art=$ART)"

# ── 3. bin helpers on PATH ───────────────────────────────────────────────────
LBIN="$HOME/.local/bin"; mkdir -p "$LBIN"
ln -sf "$SHELL_DIR/bin/prompt-preview" "$LBIN/prompt-preview"
ln -sf "$SHELL_DIR/motd/motd.sh"       "$LBIN/motd"
echo "✔ linked prompt-preview + motd into $LBIN"

# ── 4. optional extras ───────────────────────────────────────────────────────
pkg_install() {  # best-effort, cross-distro
  if   command -v dnf     >/dev/null; then sudo dnf install -y "$@"
  elif command -v apt-get >/dev/null; then sudo apt-get update -qq && sudo apt-get install -y "$@"
  else echo "  (no dnf/apt — install $* by hand)"; return 1; fi
}

if $WITH_FONTS; then
  echo "→ installing chafa + figlet + lolcat (live MOTD portraits + art generator)"
  pkg_install chafa figlet lolcat || pkg_install chafa || true
fi

if $WITH_STARSHIP; then
  if ! command -v starship >/dev/null; then
    echo "→ installing starship"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y || \
      echo "  starship install failed — see https://starship.rs"
  fi
fi

echo
echo "Done. Open a new shell, or run:  source \"$COMMON\""
echo "Try:  hl list   ·   hl theme modern   ·   hl motd"
