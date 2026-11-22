#!/usr/bin/env bash
# Bump chatgpt-linux to whatever OpenAI currently serves at the mutable
# `latest` URL: download once, read the Debian version, rewrite version + hash.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
nix_file="$here/package.nix"
url=$(sed -n 's/^ *url = "\(.*chatgpt_amd64\.deb\)";/\1/p' "$nix_file")

{ read -r base32; read -r path; } < <(nix-prefetch-url --print-path "$url")
hash=$(nix hash convert --hash-algo sha256 --to sri "$base32")
version=$(nix shell nixpkgs#dpkg -c dpkg-deb -f "$path" Version)

sed -i \
  -e "s|^\(  version = \)\"[^\"]*\";|\1\"$version\";|" \
  -e "s|^\(    hash = \)\"sha256-[^\"]*\";|\1\"$hash\";|" \
  "$nix_file"

echo "chatgpt-linux -> $version ($hash)"
