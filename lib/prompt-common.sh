#!/usr/bin/env bash
# shell/lib/prompt-common.sh
#
# Shared building blocks for the bash PS1 themes: git status, exit-code glyphs,
# SSH/root markers, command timing. Kept theme-agnostic so simple/fancy/modern
# can mix and match. Everything here is cheap — no forks in the hot path beyond
# a couple of git plumbing calls, gated on actually being in a repo.

# Fast git branch + dirty flag. Returns nothing when not in a work tree.
# Sets reply in $REPLY to avoid a subshell in the prompt.
hl_git_info() {
  REPLY=""
  # `git rev-parse` is the cheapest "are we in a repo" probe.
  local branch
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || \
    branch=$(git rev-parse --short HEAD 2>/dev/null) || return 0
  local dirty=""
  # --no-optional-locks keeps prompts from fighting a background git process.
  if [[ -n "$(git --no-optional-locks status --porcelain 2>/dev/null)" ]]; then
    dirty="*"
  fi
  REPLY="${branch}${dirty}"
}

# Same idea but split so themes can colour dirty/clean differently.
# Sets HL_GIT_BRANCH and HL_GIT_DIRTY ("" or "*").
hl_git_split() {
  HL_GIT_BRANCH=""; HL_GIT_DIRTY=""
  HL_GIT_BRANCH=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) || \
    HL_GIT_BRANCH=$(git rev-parse --short HEAD 2>/dev/null) || return 0
  [[ -n "$(git --no-optional-locks status --porcelain 2>/dev/null)" ]] && HL_GIT_DIRTY="*"
}

# Are we logged in over SSH? (covers the common envs)
hl_is_ssh() { [[ -n "${SSH_CONNECTION:-}${SSH_TTY:-}${SSH_CLIENT:-}" ]]; }

# Are we root?
hl_is_root() { [[ "$(id -u)" -eq 0 ]]; }

# Human-readable seconds (used by command timing). 90 -> 1m30s
hl_human_secs() {
  local s=$1
  if   (( s < 60 ));   then printf '%ds' "$s"
  elif (( s < 3600 )); then printf '%dm%ds' $(( s/60 )) $(( s%60 ))
  else printf '%dh%dm' $(( s/3600 )) $(( (s%3600)/60 )); fi
}

# Command-timing hooks. Themes opt in by calling hl_timer_enable once; the
# elapsed seconds of the last command land in HL_LAST_DURATION (or "" if <
# HL_TIMER_THRESHOLD, default 3s, so trivial commands don't clutter the prompt).
HL_TIMER_THRESHOLD=${HL_TIMER_THRESHOLD:-3}
hl_timer_start() { HL_TIMER_T0=${HL_TIMER_T0:-$SECONDS}; }
hl_timer_stop() {
  HL_LAST_DURATION=""
  if [[ -n "${HL_TIMER_T0:-}" ]]; then
    local d=$(( SECONDS - HL_TIMER_T0 ))
    (( d >= HL_TIMER_THRESHOLD )) && HL_LAST_DURATION="$(hl_human_secs "$d")"
    unset HL_TIMER_T0
  fi
}
hl_timer_enable() {
  # DEBUG trap fires before each command; PROMPT_COMMAND runs hl_timer_stop.
  trap 'hl_timer_start' DEBUG
  case "${PROMPT_COMMAND:-}" in
    *hl_timer_stop*) : ;;
    *) PROMPT_COMMAND="hl_timer_stop;${PROMPT_COMMAND:-}" ;;
  esac
}
