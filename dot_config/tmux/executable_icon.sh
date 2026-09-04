#!/usr/bin/env bash
# Nerd Font glyph for a pane's foreground command
# $1 is #{pane_current_command}, $2 is #{pane_pid}

glyph() {
  case "${1##*/}" in
    cargo|rustc|rust-analyzer|bacon) printf '' ;;
    nvim)                            printf '' ;;
    vim|view)                        printf '' ;;
    git|lazygit|gh)                  printf '' ;;
    docker|container)                printf '' ;;
    python|python3)                  printf '' ;;
    lua|luajit|lua-language-server)  printf '' ;;
    node|npm|npx|bun|deno)           printf '' ;;
    go|gopls|dlv)                    printf '' ;;
    ssh|mosh)                        printf '󰌘' ;;
    pi|omp|opencode|codex|claude)    printf '󰚩' ;;
    *)                               return 1 ;;
  esac
}

cmd="${1##*/}"

case "$cmd" in
  node|npm|npx|bun|deno|python|python3) ambiguous=1 ;;
  *) glyph "$cmd" && exit 0; ambiguous=1 ;;
esac

if [ -n "${2:-}" ] && [ -n "${ambiguous:-}" ]; then
  child=$(pgrep -P "$2" 2>/dev/null | head -1)
  if [ -n "$child" ]; then
    real=$(ps -o comm= -p "$child" 2>/dev/null | tr -d ' ')
    [ "${real##*/}" != "$cmd" ] && glyph "$real" && exit 0
  fi
fi

glyph "$cmd" || printf ''
