#!/usr/bin/env bash
# Static analysis of a project's source code with Semgrep.
# Uses the public rule packs plus our own rules in configs/semgrep/rules.
# Usage: scan-code.sh [project-dir]
# Exit codes: 0 = no blocking findings, 1 = blocking findings, 2 = scanner error.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
report_dir="${REPORT_DIR:-$PWD/reports}"
mkdir -p "$report_dir"
report="$report_dir/semgrep.json"

cd "${1:-.}" || exit 2

semgrep scan \
  --config p/default \
  --config p/owasp-top-ten \
  --config "$root/configs/semgrep/rules" \
  --metrics off --disable-version-check \
  --json-output "$report" --sarif-output "$report_dir/semgrep.sarif" \
  .
code=$?

# Without --error Semgrep exits 0 whether or not it has findings, so anything else is a failure.
if [ "$code" -ne 0 ]; then
  echo "semgrep failed (exit $code)." >&2
  exit 2
fi

total="$(jq '.results | length' "$report")" || exit 2
blocking="$(jq -r '
  .results[] | select(.extra.severity | IN("ERROR", "HIGH", "CRITICAL"))
  | "\(.path):\(.start.line)  \(.check_id)"' "$report")" || exit 2
blocking_count="$(printf '%s\n' "$blocking" | grep -c .)"

echo
echo "$total finding(s), $blocking_count blocking."
if [ "$blocking_count" -gt 0 ]; then
  echo "Blocking:"
  printf '%s\n' "$blocking" | sed 's/^/  /'
  exit 1
fi
exit 0
