#!/usr/bin/env bash
# Claude Code status line
# Layout: <dir> · <branch> · PR#<n> · <model> · ctx <bar> <pct>% · 5h <bar> <pct>%
# Reads the session JSON on stdin. The PR lookup hits the network, so it is
# cached per repo+branch and refreshed in the background to keep this fast.
# Inside the neovim float the dir and branch are dropped

input=$(cat)

# pull every field we need in a single jq pass, emitted as shell assignments
eval "$(printf '%s' "$input" | jq -r '
  @sh "MODEL=\(.model.display_name // "?")",
  @sh "DIR=\(.workspace.current_dir // .cwd // "")",
  @sh "CTX=\((.context_window.used_percentage // -1) | floor)",
  @sh "FIVE=\((.rate_limits.five_hour.used_percentage // -1) | floor)",
  @sh "RESET=\((.rate_limits.five_hour.resets_at // -1) | floor)"
')"

# colors
RST=$'\033[0m'; DIM=$'\033[2m'; BLD=$'\033[1m'
CYAN=$'\033[36m'; BLUE=$'\033[34m'; MAG=$'\033[35m'
GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'

SEP=" ${DIM}·${RST} "

out=""
add() { # append a segment, separated only when one already precedes it
  [ -n "$out" ] && out+="$SEP"
  out+="$1"
}

lvlcol() { # pct -> severity color
  local p=$1
  if   (( p >= 80 )); then printf '%s' "$RED"
  elif (( p >= 50 )); then printf '%s' "$YEL"
  else                     printf '%s' "$GRN"
  fi
}

bar() { # pct width -> colored filled/empty block bar
  local pct=$1 w=${2:-10} i filled empty col s
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  filled=$(( (pct * w + 50) / 100 ))
  empty=$(( w - filled ))
  col=$(lvlcol "$pct")
  s="$col"
  for ((i=0; i<filled; i++)); do s+="█"; done
  s+="$DIM"
  for ((i=0; i<empty; i++)); do s+="░"; done
  s+="$RST"
  printf '%s' "$s"
}

# directory, skipped in the nvim float
if [ -z "$CLAUDE_NVIM_FLOAT" ]; then
  if [ "$DIR" = "$HOME" ]; then
    name="~"
  else
    name=$(basename "$DIR")
  fi
  [ -z "$name" ] && name="~"
  add "${BLD}${CYAN}${name}${RST}"
fi

# git branch + PR. the branch is still resolved in the float because the PR
# lookup keys off it, but only the PR is printed there
branch=$(git -C "$DIR" branch --show-current 2>/dev/null)
[ -z "$branch" ] && branch=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  [ -z "$CLAUDE_NVIM_FLOAT" ] && add "${MAG}${branch}${RST}"

  root=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)
  cdir="$HOME/.claude/.cache/statusline"
  mkdir -p "$cdir" 2>/dev/null
  key=$(printf '%s' "${root}:${branch}" | md5 2>/dev/null || printf '%s' "${root}:${branch}" | md5sum 2>/dev/null | cut -d' ' -f1)
  cf="$cdir/pr-$key"

  now=$(date +%s)
  fresh=0
  if [ -f "$cf" ]; then
    mtime=$(stat -f %m "$cf" 2>/dev/null || stat -c %Y "$cf" 2>/dev/null || echo 0)
    (( now - mtime < 60 )) && fresh=1
  fi
  if (( fresh == 0 )); then
    # refresh in the background, detached, so the status line never blocks on gh
    ( cd "$root" 2>/dev/null && gh pr list --head "$branch" --state open \
        --json number --jq '.[0].number // empty' > "$cf.tmp" 2>/dev/null \
        && mv "$cf.tmp" "$cf" 2>/dev/null ) >/dev/null 2>&1 &
    disown 2>/dev/null
  fi

  pr=""
  [ -f "$cf" ] && pr=$(cat "$cf" 2>/dev/null)
  [ -n "$pr" ] && add "${GRN}PR#${pr}${RST}"
fi

# model
add "${BLUE}${MODEL}${RST}"

# context window bar
if [ "$CTX" -ge 0 ] 2>/dev/null; then
  add "${DIM}ctx${RST} $(bar "$CTX" 8) $(lvlcol "$CTX")${CTX}%${RST}"
fi

# 5-hour rolling usage bar, with shorthand reset clock time in parens
if [ "$FIVE" -ge 0 ] 2>/dev/null; then
  seg="${DIM}5h${RST} $(bar "$FIVE" 6) $(lvlcol "$FIVE")${FIVE}%${RST}"
  if [ "$RESET" -gt 0 ] 2>/dev/null; then
    (( RESET > 100000000000 )) && RESET=$(( RESET / 1000 ))   # ms -> s safety
    rt=$(date -r "$RESET" '+%-I:%M%p' 2>/dev/null || date -d "@$RESET" '+%-I:%M%p' 2>/dev/null)
    if [ -n "$rt" ]; then
      rt=$(printf '%s' "$rt" | tr 'APM' 'apm'); rt=${rt%m}   # 3:45PM -> 3:45p
      seg+=" ${DIM}(${rt})${RST}"
    fi
  fi
  add "$seg"
fi

printf '%s' "$out"
