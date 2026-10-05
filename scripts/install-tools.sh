#!/usr/bin/env bash
# Installs pinned scanner versions on a Linux x64 machine (the GitHub-hosted runners).
# Every download is checked against a known checksum before it is installed.
# Usage: install-tools.sh <tool> [<tool> ...]
set -euo pipefail

# Keep these versions in step with scripts/local-scan.ps1.
GITLEAKS_VERSION="8.30.1"
GITLEAKS_SHA256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
OSV_SCANNER_VERSION="2.6.0"
OSV_SCANNER_SHA256="ca69b3d3cd08f889a49dc0a383122f71cc528b83803671df5fd874d97485b108"

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

download() { # download <url> <sha256> <destination>
  curl --fail --silent --show-error --location --retry 3 --output "$3" "$1"
  echo "$2  $3" | sha256sum --check --quiet -
}

install_gitleaks() {
  download "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
    "$GITLEAKS_SHA256" "$tmp/gitleaks.tar.gz"
  tar -xzf "$tmp/gitleaks.tar.gz" -C "$tmp" gitleaks
  install -m 0755 "$tmp/gitleaks" "$BIN_DIR/gitleaks"
}

install_osv_scanner() {
  download "https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_linux_amd64" \
    "$OSV_SCANNER_SHA256" "$tmp/osv-scanner"
  install -m 0755 "$tmp/osv-scanner" "$BIN_DIR/osv-scanner"
}

for tool in "$@"; do
  case "$tool" in
    gitleaks) install_gitleaks ;;
    osv-scanner) install_osv_scanner ;;
    *) echo "install-tools.sh: unknown tool '$tool'" >&2; exit 2 ;;
  esac
  echo "Installed $tool"
done

# Make the tools visible to later workflow steps.
if [ -n "${GITHUB_PATH:-}" ]; then echo "$BIN_DIR" >> "$GITHUB_PATH"; fi
