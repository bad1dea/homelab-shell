#!/usr/bin/env bash
# shell/themes/simple.sh — one clean line, everything you need, nothing you don't.
#
#   ⬡ user@hermes ~/homelab (main*) $
#
# Host coloured by character. Git shown in parens when present. The trailing
# $/# turns red after a failed command so you still get an error signal.

__hl_set_prompt() {
  local ec=$?
  local c_host;  c_host="$(fut_fg_p "$FUT_C256" "$FUT_C16")"
  local c_dim;   c_dim="$(fut_fg_p 245 90)"
  local c_path;  c_path="$(fut_fg_p 153 36)"
  local c_git;   c_git="$(fut_fg_p 114 32)"
  local c_err;   c_err="$(fut_fg_p 203 31)"
  local r;       r="$(fut_reset_p)"

  local userc="$c_dim"; hl_is_root && userc="$c_err"
  local p="${c_host}${FUT_GLYPH} ${userc}\u@${c_host}\h${r} ${c_path}\w${r}"

  hl_git_info
  [[ -n "$REPLY" ]] && p+=" ${c_git}(${REPLY})${r}"

  local sig="\$"; hl_is_root && sig="#"
  local c_sig="$c_dim"; (( ec != 0 )) && c_sig="$c_err"
  PS1="${p} ${c_sig}${sig}${r} "
}
