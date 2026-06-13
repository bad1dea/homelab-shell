#!/usr/bin/env bash
# shell/themes/fancy.sh — the flagship two-line prompt.
#
# Line 1:  ⬡ user@hermes  ~/homelab  on main*  ✗1  ⏱ 4s
# Line 2:  ❯                         (turns red after a failed command)
#
# Host name + glyph wear the character's colour (futurama.sh). Git branch, a
# dirty star, the last exit code, and command timing only appear when relevant.
# Built every prompt via __hl_set_prompt so it stays live.

hl_timer_enable

__hl_set_prompt() {
  local ec=$?                      # MUST be first — capture last exit code

  local c_host;  c_host="$(fut_fg_p "$FUT_C256" "$FUT_C16")"
  local c_dim;   c_dim="$(fut_fg_p 245 90)"
  local c_path;  c_path="$(fut_fg_p 153 36)"
  local c_git;   c_git="$(fut_fg_p 114 32)"
  local c_dirty; c_dirty="$(fut_fg_p 215 33)"
  local c_err;   c_err="$(fut_fg_p 203 31)"
  local c_ok;    c_ok="$(fut_fg_p 114 32)"
  local r;       r="$(fut_reset_p)"

  # user@host with root in red
  local userc="$c_dim"; hl_is_root && userc="$c_err"
  local line1="${c_host}${FUT_GLYPH} ${userc}\u${c_dim}@${c_host}\h${r}"
  line1+="  ${c_path}\w${r}"

  # git
  hl_git_split
  if [[ -n "$HL_GIT_BRANCH" ]]; then
    line1+="  ${c_dim}on ${c_git}${HL_GIT_BRANCH}${c_dirty}${HL_GIT_DIRTY}${r}"
  fi

  # last exit code (only on failure)
  (( ec != 0 )) && line1+="  ${c_err}✗${ec}${r}"

  # command timing
  [[ -n "${HL_LAST_DURATION:-}" ]] && line1+="  ${c_dim}⏱ ${HL_LAST_DURATION}${r}"

  # line 2 prompt char: green ❯ normally, red after failure; '#' for root
  local pc="❯"; hl_is_root && pc="#"
  local c_pc="$c_ok"; (( ec != 0 )) && c_pc="$c_err"
  PS1="\n${line1}\n${c_pc}${pc}${r} "
}
