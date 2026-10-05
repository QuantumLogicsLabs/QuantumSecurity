#!/usr/bin/env bash
# Proves the scans still catch what they are meant to catch.
# Builds two throwaway projects, one with a planted problem for each scan and one
# clean, then checks that every scan flags the first and passes the second.
# Needs gitleaks, osv-scanner, semgrep and jq on PATH (scripts/install-tools.sh installs the first three).
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

expect() { # expect <exit-code> <description> <command...>
  local want="$1" description="$2" got
  shift 2
  REPORT_DIR="$work/reports" "$@" > "$work/output.log" 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then
    echo "ok    $description"
  else
    echo "FAIL  $description (expected exit $want, got $got)"
    tail -n 60 "$work/output.log" | sed 's/^/      | /'
    failures=$((failures + 1))
  fi
}

commit_all() { # commit_all <repo> <message>
  git -C "$1" add -A
  git -C "$1" -c user.name=selftest -c user.email=selftest@example.com commit -q -m "$2"
}

# --- A project with one planted problem per scan -----------------------------
bad="$work/vulnerable"
mkdir -p "$bad"
git -C "$bad" init -q

# The secret is assembled here so that this script never contains a string the scan would flag.
printf 'MONGO_URI=%s://%s:%s@%s\n' 'mongodb+srv' 'quantum_app' "$(openssl rand -hex 12)" \
  'cluster0.ab1cd.mongodb.net/chat' > "$bad/settings.txt"
commit_all "$bad" "Add settings"
# Deleting the file does not remove it from history, so the scan must still find it.
git -C "$bad" rm -q settings.txt

cat > "$bad/package.json" <<'JSON'
{ "name": "selftest", "version": "1.0.0", "dependencies": { "lodash": "4.17.15" } }
JSON
cat > "$bad/package-lock.json" <<'JSON'
{
  "name": "selftest",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": { "name": "selftest", "version": "1.0.0", "dependencies": { "lodash": "4.17.15" } },
    "node_modules/lodash": {
      "version": "4.17.15",
      "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.15.tgz"
    }
  }
}
JSON
cat > "$bad/server.js" <<'JS'
const jwt = require("jsonwebtoken");
const secret = process.env.JWT_SECRET || "changeme";
module.exports = (user) => jwt.sign({ id: user.id }, secret, { expiresIn: "15m" });
JS
commit_all "$bad" "Add app"

# --- A clean project ---------------------------------------------------------
good="$work/clean"
mkdir -p "$good"
git -C "$good" init -q
# A placeholder connection string must not be reported as a secret.
printf '# Clean project\n\nSet MONGO_URI to mongodb+srv://<user>:<password>@cluster.example.net/app\n' > "$good/README.md"
cat > "$good/server.js" <<'JS'
const secret = process.env.JWT_SECRET;
if (!secret) throw new Error("JWT_SECRET is not set");
module.exports = { secret };
JS
commit_all "$good" "Initial commit"

# --- Checks ------------------------------------------------------------------
expect 1 "secrets scan flags a secret that was committed and later deleted" \
  bash "$root/scripts/scan-secrets.sh" "$bad"
expect 1 "dependency scan flags a package with a high-severity vulnerability" \
  bash "$root/scripts/scan-dependencies.sh" "$bad"
expect 1 "code scan flags a hardcoded secret fallback" \
  bash "$root/scripts/scan-code.sh" "$bad"

expect 0 "secrets scan passes a clean project" bash "$root/scripts/scan-secrets.sh" "$good"
expect 0 "dependency scan passes a clean project" bash "$root/scripts/scan-dependencies.sh" "$good"
expect 0 "code scan passes a clean project" bash "$root/scripts/scan-code.sh" "$good"

expect 1 "enforce mode fails the job on a blocking finding" \
  env ENFORCE=true bash "$root/scripts/ci-run.sh" secrets "$bad"
expect 0 "report-only mode reports the finding without failing the job" \
  env ENFORCE=false bash "$root/scripts/ci-run.sh" secrets "$bad"

# The local script runs the scanners from their Docker images, so it is checked separately.
if command -v pwsh > /dev/null && command -v docker > /dev/null; then
  local_scan=(pwsh -NoProfile -File "$root/scripts/local-scan.ps1")
  expect 1 "local-scan.ps1 flags the planted secret" "${local_scan[@]}" -Project "$bad" -Scan secrets
  expect 1 "local-scan.ps1 flags the vulnerable package" "${local_scan[@]}" -Project "$bad" -Scan dependencies
  expect 1 "local-scan.ps1 flags the insecure code" "${local_scan[@]}" -Project "$bad" -Scan code
  expect 0 "local-scan.ps1 passes a clean project" "${local_scan[@]}" -Project "$good"
else
  echo "skip  local-scan.ps1 checks (they need pwsh and docker)"
fi

echo
if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All checks passed."
