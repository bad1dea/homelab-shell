#!/usr/bin/env bash
# shell/themes/minimal.sh — for when you want to forget the shell is even there.
#
#   ~/homelab ❯            (over SSH it prepends the host glyph so you still
#   ⬡ ~/homelab ❯           know you're not on the local box)
#
# No user@host noise locally; just the basename of the dir colour-cued to the
# host. The ❯ goes red on error. Git is a single dot when dirty.

__hl_set_prompt() {
  local ec=$?
  local c_host;  c_host="$(fut_fg_p "$FUT_C256" "$FUT_C16")"
  local c_path;  c_path="$(fut_fg_p 245 37)"
  local c_err;   c_err="$(fut_fg_p 203 31)"
  local c_ok;    c_ok="$(fut_fg_p 114 32)"
  local r;       r="$(fut_reset_p)"

  local p=""
  # Only advertise the host when remote (or root) — that's when it matters.
  if hl_is_ssh || hl_is_root; then p="${c_host}${FUT_GLYPH} ${r}"; fi
  p+="${c_path}\W${r}"

  hl_git_info
  [[ "$REPLY" == *"*" ]] && p+="${c_host}•${r}"

  local pc="❯"; hl_is_root && pc="#"
  local c_pc="$c_ok"; (( ec != 0 )) && c_pc="$c_err"
  PS1="${p} ${c_pc}${pc}${r} "
}
