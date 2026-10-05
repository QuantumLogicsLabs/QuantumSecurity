#!/usr/bin/env bash
# Checks every lockfile under a project for dependencies with known vulnerabilities (OSV-Scanner).
# Covers npm, yarn, pnpm, pip, Poetry, Go, Cargo, Maven and more, in any subfolder.
# Usage: scan-dependencies.sh [project-dir]
# Environment: SEVERITY_THRESHOLD - lowest CVSS score that blocks (default 7.0, i.e. high and critical).
# Exit codes: 0 = nothing at or above the threshold, 1 = blocking vulnerabilities, 2 = scanner error.
set -uo pipefail

threshold="${SEVERITY_THRESHOLD:-7.0}"
report_dir="${REPORT_DIR:-$PWD/reports}"
mkdir -p "$report_dir"
report="$report_dir/osv.json"

cd "${1:-.}" || exit 2

# OSV-Scanner reads lockfiles, so a package.json without one is not checked at all.
while IFS= read -r manifest; do
  dir="$(dirname "$manifest")"
  if [ ! -e "$dir/package-lock.json" ] && [ ! -e "$dir/yarn.lock" ] && [ ! -e "$dir/pnpm-lock.yaml" ]; then
    echo "::warning title=Dependencies not scanned::$manifest has no lockfile. Commit package-lock.json so its dependencies can be checked."
  fi
done < <(find . -name package.json -not -path '*/node_modules/*' -not -path './.git/*')

osv-scanner scan source --recursive --format json --output-file "$report" .
code=$?

case "$code" in
  0) echo "No known vulnerabilities."; exit 0 ;;
  128) echo "No lockfiles found, nothing to scan."; exit 0 ;;
  1) ;;
  *) echo "osv-scanner failed (exit $code)." >&2; exit 2 ;;
esac

# One row per vulnerability, highest CVSS score first.
rows="$(jq -r '
  [ .results[]? | .source.path as $source | .packages[]? | .package as $package | .groups[]?
    | { score: ((.max_severity // "") | tonumber? // null),
        package: "\($package.name)@\($package.version)",
        ids: (.ids | join(", ")),
        source: $source } ]
  | sort_by(.score // -1) | reverse | .[]
  | [ (.score // "unknown" | tostring), .package, .ids, .source ] | @tsv' "$report")" || exit 2

printf 'CVSS\tPACKAGE\tADVISORY\tLOCKFILE\n%s\n' "$rows" | column -t -s "$(printf '\t')"

total="$(printf '%s\n' "$rows" | grep -c .)"
blocking="$(printf '%s\n' "$rows" | awk -F '\t' -v t="$threshold" '$1 != "unknown" && $1 + 0 >= t + 0' | grep -c .)"
echo
echo "$total vulnerable dependency finding(s), $blocking at or above CVSS $threshold."

if [ "$blocking" -gt 0 ]; then exit 1; fi
exit 0
