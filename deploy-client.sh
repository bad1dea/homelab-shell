#!/usr/bin/env bash
# deploy-client.sh
#
# Push this shell setup (Futurama prompt + MOTD) out to a machine over SSH —
# a laptop/desktop (fry/leela/...), or any other box. Standalone: the target
# only needs this small public repo, not the private homelab repo.
#
# Auth: tries your SSH key first; if that fails, falls straight through to an
# interactive password prompt (no BatchMode) — works whether or not you've
# copied a key to the target yet.
#
# What it does on the target (idempotent):
#   - clone this repo to ~/.homelab-shell (or `git pull` if already there)
#   - ./install.sh --theme ... --motd ... --art ...
#   - best-effort `sudo dnf/apt install -y chafa` if missing (live portraits)
#
# Usage:
#   ./deploy-client.sh khuong@fry.local
#   ./deploy-client.sh khuong@leela 10.99.0.51
#   ./deploy-client.sh --theme modern --motd always --art shuffle khuong@fry.local

set -euo pipefail

REPO_URL="https://github.com/bad1dea/homelab-shell.git"
THEME="fancy"; MOTD="auto"; ART="host"
TARGETS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme) THEME="$2"; shift 2 ;;
    --motd)  MOTD="$2";  shift 2 ;;
    --art)   ART="$2";   shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done
[[ ${#TARGETS[@]} -gt 0 ]] || { echo "usage: $0 [--theme T] [--motd M] [--art A] user@host [user@host...]" >&2; exit 2; }

# Try key auth first (no prompt); fall back to normal interactive auth
# (password) if that doesn't work. Either way StrictHostKeyChecking won't
# block on a new host.
SSH_OPTS_KEY=(-o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -o BatchMode=yes)
SSH_OPTS_PW=(-o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o PreferredAuthentications=keyboard-interactive,password -o PubkeyAuthentication=no)

remote_script() {
  cat <<REMOTE
set -euo pipefail
theme="\$1"; motd="\$2"; art="\$3"
DIR="\$HOME/.homelab-shell"

if [[ -d "\$DIR/.git" ]]; then
  git -C "\$DIR" pull --ff-only --quiet
  echo "    ✔ git pull (\$(git -C "\$DIR" rev-parse --short HEAD))"
else
  git clone --quiet "$REPO_URL" "\$DIR"
  echo "    ✔ cloned to \$DIR"
fi

bash "\$DIR/install.sh" --theme "\$theme" --motd "\$motd" --art "\$art" >/dev/null
echo "    ✔ shell wired (theme=\$theme motd=\$motd art=\$art)"

if ! command -v chafa >/dev/null 2>&1; then
  if sudo -n true 2>/dev/null; then
    if   command -v apt-get >/dev/null; then sudo -n apt-get install -y -qq chafa >/dev/null 2>&1
    elif command -v dnf     >/dev/null; then sudo -n dnf install -y chafa >/dev/null 2>&1; fi
  fi
  command -v chafa >/dev/null 2>&1 && echo "    ✔ chafa installed (live portraits)" \\
                                   || echo "    · chafa unavailable — using baked-in .ans portraits (sudo dnf/apt install chafa to enable live render)"
fi
REMOTE
}

rc=0
for target in "${TARGETS[@]}"; do
  echo; echo "==> $target"
  if ssh "${SSH_OPTS_KEY[@]}" "$target" true 2>/dev/null; then
    echo "    (key auth)"
    ssh "${SSH_OPTS_KEY[@]}" "$target" bash -s -- "$THEME" "$MOTD" "$ART" < <(remote_script) || { echo "    FAILED" >&2; rc=1; }
  else
    echo "    (key auth unavailable — falling back to password)"
    ssh "${SSH_OPTS_PW[@]}" "$target" bash -s -- "$THEME" "$MOTD" "$ART" < <(remote_script) || { echo "    FAILED" >&2; rc=1; }
  fi
done

echo
if [[ $rc -eq 0 ]]; then
  echo "==> Done. New shells on ${TARGETS[*]} get the prompt + MOTD. Try: hl motd"
else
  echo "==> Done with errors (see FAILED targets above)." >&2
fi
exit $rc
