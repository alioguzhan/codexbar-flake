#!/usr/bin/env bash
# Rewrite release.json to the latest upstream CodexBar release.
#
# Hashes come from the .sha256 sidecars upstream publishes next to each asset,
# so this never downloads the ~86 MB tarballs. Verification is left to Nix: the
# fetchurl hash check plus the derivation's installCheckPhase are what actually
# gate a bump, and the workflow runs a build before committing.
#
# Exit codes: 0 = release.json is current or was updated, non-zero = failed.
set -euo pipefail

cd "$(dirname "$0")"

readonly UPSTREAM="steipete/CodexBar"

# Nix system tuple -> the CPU name upstream uses in its asset filenames.
declare -A CPUS=(
  ["x86_64-linux"]="x86_64"
  ["aarch64-linux"]="aarch64"
)

latest_tag=$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/${UPSTREAM}/releases/latest" | jq -r '.tag_name')

if [[ -z "$latest_tag" || "$latest_tag" == "null" ]]; then
  echo "could not read latest release tag from ${UPSTREAM}" >&2
  exit 1
fi

version="${latest_tag#v}"
current=$(jq -r '.version' release.json)

if [[ "$version" == "$current" ]]; then
  echo "already at ${current}"
  exit 0
fi

echo "${current} -> ${version}"

updated=$(jq --arg version "$version" '.version = $version' release.json)

for system in "${!CPUS[@]}"; do
  cpu="${CPUS[$system]}"
  asset="CodexBarCLI-v${version}-linux-musl-${cpu}.tar.gz"
  url="https://github.com/${UPSTREAM}/releases/download/${latest_tag}/${asset}.sha256"

  # Sidecar format is `<hex>  <path>`; the path is the builder's temp dir.
  hex=$(curl -fsSL "$url" | awk '{print $1}')

  if [[ ! "$hex" =~ ^[0-9a-f]{64}$ ]]; then
    echo "unexpected sha256 sidecar contents at ${url}: '${hex}'" >&2
    exit 1
  fi

  sri=$(nix hash convert --hash-algo sha256 --to sri "$hex")
  echo "  ${system}: ${sri}"

  updated=$(jq --arg system "$system" --arg sri "$sri" '.hashes[$system] = $sri' <<<"$updated")
done

printf '%s\n' "$updated" >release.json
