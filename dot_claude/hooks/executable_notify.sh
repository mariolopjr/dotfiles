#!/bin/bash
# terminal-notifier bridge for Claude Code Notification/Stop hooks
set -euo pipefail

command -v terminal-notifier >/dev/null || exit 0

IFS=$'\t' read -r event msg dir sid < <(
  jq -r '[.hook_event_name // "", .message // "", .cwd // "", .session_id // ""] | @tsv'
)

[ -n "$msg" ] || msg="Turn finished"
[ "$event" = "Stop" ] && title="Claude Code done" || title="Claude Code"

# ponytail: click-to-focus hardcoded to ghostty
terminal-notifier \
  -title "$title" \
  -subtitle "${dir##*/}" \
  -message "$msg" \
  -group "claude-${sid:-none}" \
  -activate com.mitchellh.ghostty
