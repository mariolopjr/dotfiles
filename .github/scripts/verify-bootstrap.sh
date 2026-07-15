#!/usr/bin/env bash

# Validate the machine chezmoi just bootstrapped is configured as expected
#
# Casks, App Store apps, the Dock and macOS defaults are not installed in CI, so
# nothing here may depend on them

set -uo pipefail

fail=0
ok() { printf '  \033[32mok\033[0m   %s\n' "$*"; }
bad() {
  printf '  \033[31mFAIL\033[0m %s\n' "$*"
  fail=1
}

log="$(mktemp -d)"
trap 'rm -rf "$log"' EXIT

echo "==> chezmoi agrees the target matches the source"
if chezmoi verify; then
  ok "chezmoi verify"
else
  bad "chezmoi verify found unapplied differences"
fi

echo "==> entrypoints landed in \$HOME"
for f in \
  .zshrc \
  .config/fish/config.fish \
  .config/nvim/init.lua \
  .config/nvim/lazy-lock.json \
  .config/wezterm/wezterm.lua \
  .config/mise/config.toml \
  .hammerspoon/init.lua; do
  if [ -e "$HOME/$f" ]; then
    ok "$f"
  else
    bad "$f is missing"
  fi
done

echo "==> tools the config expects are on PATH"
for bin in nvim fish rg fd bat jq git delta mise lazygit stylua; do
  if command -v "$bin" >/dev/null 2>&1; then
    ok "$bin"
  else
    bad "$bin is not on PATH"
  fi
done

echo "==> fish parses its config and starts"
if fish -c 'true' >"$log/fish.txt" 2>&1; then
  ok "fish -c starts cleanly"
else
  bad "fish failed to start"
  cat "$log/fish.txt"
fi

# tide is configured by a run_once script
if fish -c 'functions -q tide' >/dev/null 2>&1; then
  ok "tide prompt installed by fisher"
else
  bad "tide is not installed, the fisher script did not take"
fi

echo "==> neovim restores its plugins from the lockfile"
# --headless still exits 0 on a lua error inside init.lua
# inspect the output to determine if neovim config is correct
if ! nvim --headless "+Lazy! restore" +qa >"$log/lazy.txt" 2>&1; then
  bad "nvim exited nonzero during Lazy restore"
fi
if grep -qiE '^(E[0-9]+:|Error)|stack traceback' "$log/lazy.txt"; then
  bad "errors during Lazy restore"
  cat "$log/lazy.txt"
else
  ok "Lazy restore clean"
fi

echo "==> neovim loads the full config without errors"
if ! nvim --headless -c 'lua io.write("loaded\n")' -c 'qa!' >"$log/nvim.txt" 2>&1; then
  bad "nvim exited nonzero loading the config"
fi
if grep -qiE '^(E[0-9]+:|Error)|stack traceback' "$log/nvim.txt"; then
  bad "errors loading the neovim config"
  cat "$log/nvim.txt"
elif grep -q loaded "$log/nvim.txt"; then
  ok "config loaded"
else
  bad "nvim never reached the end of init.lua"
  cat "$log/nvim.txt"
fi

if ((fail)); then
  echo
  echo "bootstrap verification failed"
  exit 1
fi
echo
echo "bootstrap is usable"
