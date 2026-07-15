#!/usr/bin/env bash

# Verify every package in .chezmoidata/packages.toml still exists and is
# installable without installing anything
#
# Run from the chezmoi source directory

set -uo pipefail

fail=0
note() { printf '  %s\n' "$*"; }
bad() {
  printf '  \033[31mFAIL\033[0m %s\n' "$*"
  fail=1
}
warn() { printf '  \033[33mWARN\033[0m %s\n' "$*"; }

cache="$(mktemp -d)"
trap 'rm -rf "$cache"' EXIT

data="$cache/data.json"
chezmoi data --source "$PWD" --format json >"$data"

# macOS ships bash 3.2, so no mapfile
taps=()
brews=()
casks=()
mas_ids=()

while IFS= read -r line; do taps+=("$line"); done < <(jq -r '.packages.darwin.taps[]?' "$data")
# a brew is either a bare name or { name, args } for extras like HEAD
while IFS= read -r line; do brews+=("$line"); done < <(jq -r '.packages.darwin.brews[]? | if type == "object" then .name else . end' "$data")
# shared casks plus every host-specific list
while IFS= read -r line; do casks+=("$line"); done < <(jq -r '[.packages.darwin.casks[]?, (.packages.darwin.hosts[]?.casks[]?)] | unique[]' "$data")
while IFS= read -r line; do mas_ids+=("$line"); done < <(jq -r '.packages.darwin.mas[]? | "\(.id)\t\(.name)"' "$data")

curl -fsSL https://formulae.brew.sh/api/formula.json -o "$cache/formula.json"
curl -fsSL https://formulae.brew.sh/api/cask.json -o "$cache/cask.json"

# name: "state<TAB>detail" lookups covering aliases and old names so a package
# renamed upstream still resolves the way brew would resolve it
jq -r '.[] | . as $f | ([$f.name, $f.full_name] + $f.aliases + $f.oldnames | map(select(. != null)) | unique)[]
       | "\(.)\t\(if $f.disabled then "disabled" elif $f.deprecated then "deprecated" else "ok" end)\t\([$f.deprecation_reason // $f.disable_reason // empty, (if $f.disable_date then "disabled on \($f.disable_date)" else empty end)] | join(", "))"' \
  "$cache/formula.json" >"$cache/formula.idx"
jq -r '.[] | . as $c | ([$c.token] + $c.old_tokens | map(select(. != null)) | unique)[]
       | "\(.)\t\(if $c.disabled then "disabled" elif $c.deprecated then "deprecated" else "ok" end)\t\([$c.deprecation_reason // $c.disable_reason // empty, (if $c.disable_date then "disabled on \($c.disable_date)" else empty end)] | join(", "))"' \
  "$cache/cask.json" >"$cache/cask.idx"

# echoes "state<TAB>detail" for a package name or "missing" if unknown
lookup() { awk -F'\t' -v k="$2" '$1 == k { print $2 "\t" $3; found = 1; exit } END { if (!found) print "missing\t" }' "$1"; }

check() {
  local kind="$1" name="$2" idx="$3" row state detail
  row="$(lookup "$idx" "$name")"
  state="${row%%$'\t'*}"
  detail="${row#*$'\t'}"
  case "$state" in
    ok) ;;
    deprecated) warn "$name is deprecated${detail:+ (${detail})}" ;;
    disabled) bad "$name is disabled and can no longer be installed${detail:+ (${detail})}" ;;
    missing) bad "$name does not exist in $kind" ;;
  esac
}

# taps testing comes first
# tapping proves the tap is reachable and works
echo "==> taps (${#taps[@]})"
for t in "${taps[@]}"; do
  if brew tap "$t" >/dev/null 2>&1; then
    note "$t"
  else
    bad "tap $t could not be tapped"
  fi
done

echo "==> formulae (${#brews[@]})"
for b in "${brews[@]}"; do
  # tap-qualified formulae are not in the core catalog so query brew directly
  if [[ "$b" == */* ]]; then
    if brew info --json=v2 --formula "$b" >/dev/null 2>&1; then
      note "$b (from tap)"
    else
      bad "$b is not available from its tap"
    fi
    continue
  fi
  check homebrew/core "$b" "$cache/formula.idx"
done

echo "==> casks (${#casks[@]})"
for c in "${casks[@]}"; do
  check homebrew/cask "$c" "$cache/cask.idx"
done

# the App Store has no bulk catalog, but the iTunes lookup endpoint confirms an
# ADAM ID still resolves to a live app
echo "==> mac app store (${#mas_ids[@]})"
for entry in "${mas_ids[@]}"; do
  id="${entry%%$'\t'*}"
  name="${entry#*$'\t'}"
  result="$(curl -fsSL "https://itunes.apple.com/lookup?id=${id}&country=us" || echo '{}')"
  if [[ "$(jq -r '.resultCount // 0' <<<"$result")" != "1" ]]; then
    bad "$name (id $id) does not resolve to an App Store app"
    continue
  fi
  # mas installs by id. The name is only a label so only flag a real rename
  actual="$(jq -r '.results[0].trackName' <<<"$result")"
  case "$actual" in
    "$name"* | "") ;;
    *) warn "id $id is now named \"$actual\", packages.toml says \"$name\"" ;;
  esac
done

if ((fail)); then
  echo
  echo "package validation failed"
  exit 1
fi
echo
echo "all packages resolve"
