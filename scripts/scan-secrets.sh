#!/usr/bin/env bash
# Scans a project for committed secrets with Gitleaks.
# A git repository is scanned through its whole history, because a secret that
# was deleted in a later commit is still readable by anyone who can clone it.
# Usage: scan-secrets.sh [project-dir]
# Exit codes: 0 = clean, 1 = secrets found, 2 = scanner error.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
report_dir="${REPORT_DIR:-$PWD/reports}"
mkdir -p "$report_dir"
report="$report_dir/gitleaks.json"

cd "${1:-.}" || exit 2

mode=dir
if [ -e .git ]; then mode=git; fi

# Leaks exit with 3 so they can be told apart from a scanner failure, which exits with 1.
gitleaks "$mode" . \
  --config "$root/configs/gitleaks.toml" \
  --report-format json --report-path "$report" \
  --redact --verbose --no-banner --exit-code 3
code=$?

case "$code" in
  0) echo "No secrets found."; exit 0 ;;
  3) echo "$(jq length "$report") secret(s) found. See docs/secret-rotation.md in QuantumSecurity."; exit 1 ;;
  *) echo "gitleaks failed (exit $code)." >&2; exit 2 ;;
esac
