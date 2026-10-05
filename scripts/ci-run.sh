#!/usr/bin/env bash
# CI wrapper: runs one scan and applies the project's enforcement mode.
# With ENFORCE=true a blocking finding fails the job; otherwise it is reported as a warning.
# A scanner that could not run always fails the job, so a broken scan is never mistaken for a clean one.
# Usage: ci-run.sh <secrets|dependencies|code> [project-dir]
set -uo pipefail

scan="$1"
target="${2:-.}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "$1" >> "$GITHUB_STEP_SUMMARY"; fi
}

bash "$here/scan-$scan.sh" "$target"
code=$?

case "$code" in
  0)
    summary "**$scan**: passed"
    exit 0
    ;;
  1)
    if [ "${ENFORCE:-true}" = "true" ]; then
      summary "**$scan**: blocking findings. Details are in the job log and the report artifact."
      exit 1
    fi
    summary "**$scan**: blocking findings, not enforced (report-only mode)"
    echo "::warning title=Security scan ($scan)::Blocking findings were reported. This project is in report-only mode, so the job was not failed."
    exit 0
    ;;
  *)
    summary "**$scan**: the scanner failed to run"
    exit "$code"
    ;;
esac
