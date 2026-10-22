#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Upstream publishes electron-updater metadata with the newest version and the
# list of artifacts. Example:
#   version: 1.0.100
#   files:
#     - url: Lolka_1.0.100_amd64.deb
meta_url="https://storage.yandexcloud.net/lolka-electron/releases/latest-linux.yml"
meta=$(curl -fsSL "$meta_url")

latest=$(sed -n 's/^version:[[:space:]]*//p' <<<"$meta" | head -n1)
if [ -z "$latest" ]; then
  echo "could not determine latest version from $meta_url" >&2
  exit 1
fi

current=$(jq -r .version sources.json 2>/dev/null || echo none)

if [ "$latest" = "$current" ]; then
  echo "up to date: $current"; exit 0
fi

base="https://storage.yandexcloud.net/lolka-electron/releases"

declare -A files=(
  [x86_64-linux]="Lolka_${latest}_amd64.deb"
)

json=$(jq -n --arg v "$latest" '{version: $v}')
for sys in "${!files[@]}"; do
  url="$base/${files[$sys]}"
  hash=$(nix store prefetch-file --json "$url" | jq -r .hash)
  json=$(jq --arg s "$sys" --arg u "$url" --arg h "$hash" \
    '.[$s] = {url: $u, hash: $h}' <<<"$json")
done

jq . <<<"$json" > sources.json
echo "updated: $current -> $latest"
echo "version=$latest" >> "${GITHUB_OUTPUT:-/dev/null}"
