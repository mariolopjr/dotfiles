#!/usr/bin/env bash
# Branch and open-PR segments for the tmux status line
#
# usage: right.sh <pane_current_path>

dir="${1:-$PWD}"

MAUVE="#[fg=#c6a0f6]"
GREEN="#[fg=#a6da95]"
RST="#[default]"

branch=$(git -C "$dir" branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
[ -z "$branch" ] && exit 0

printf '%s %s%s' "$MAUVE" "$branch" "$RST"

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
cdir="$HOME/.cache/tmux/pr"
mkdir -p "$cdir" 2>/dev/null
key=$(printf '%s' "${root}:${branch}" | md5 2>/dev/null || printf '%s' "${root}:${branch}" | md5sum 2>/dev/null | cut -d' ' -f1)
cf="$cdir/$key"

now=$(date +%s)
fresh=0
if [ -f "$cf" ]; then
  mtime=$(stat -f %m "$cf" 2>/dev/null || stat -c %Y "$cf" 2>/dev/null || echo 0)
  (( now - mtime < 60 )) && fresh=1
fi
if (( fresh == 0 )); then
  # detached refresh
  ( cd "$root" 2>/dev/null && gh pr list --head "$branch" --state open \
      --json number --jq '.[0].number // empty' > "$cf.tmp" 2>/dev/null \
      && mv "$cf.tmp" "$cf" 2>/dev/null ) >/dev/null 2>&1 &
  disown 2>/dev/null
fi

pr=""
[ -f "$cf" ] && pr=$(cat "$cf" 2>/dev/null)
[ -n "$pr" ] && printf ' %sPR#%s%s' "$GREEN" "$pr" "$RST"
