#!/usr/bin/env bash
# shell/themes/classic.sh — the nostalgic bracket prompt, lightly Futurama'd.
#
#   [user@hermes ~/homelab (main*)]$
#
# This is the muscle-memory PS1 — same shape as a default Debian/Fedora prompt,
# but the host is in its character colour so you still know where you are at a
# glance, and git rides along in the brackets. Closest thing to "stock PS1".

__hl_set_prompt() {
  local ec=$?
  local c_host;  c_host="$(fut_fg_p "$FUT_C256" "$FUT_C16")"
  local c_user;  c_user="$(fut_fg_p 114 32)"
  local c_brkt;  c_brkt="$(fut_fg_p 245 37)"
  local c_git;   c_git="$(fut_fg_p 215 33)"
  local c_err;   c_err="$(fut_fg_p 203 31)"
  local r;       r="$(fut_reset_p)"

  hl_is_root && c_user="$c_err"
  local p="${c_brkt}[${c_user}\u${c_brkt}@${c_host}\h ${c_brkt}\w"
  hl_git_info
  [[ -n "$REPLY" ]] && p+=" ${c_git}(${REPLY})${c_brkt}"
  p+="]${r}"

  local sig="\$"; hl_is_root && sig="#"
  (( ec != 0 )) && sig="${c_err}${sig}${r}"
  PS1="${p}${sig} "
}
