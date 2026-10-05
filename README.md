# QuantumSecurity

Shared security tooling for all QuantumLogicsLabs projects.

Much of our code is written with AI assistants. That code usually works, but
working is not the same as safe: it can ship with hardcoded secrets, vulnerable
packages, and endpoints that never check who is calling. This repository makes
the same security checks run on every project, from one place.

A project adds one small workflow file. The scans themselves live here, so a
new rule or a scanner update reaches every project on its next run.

> This repository is public. Never put details of an unfixed vulnerability,
> real credentials, or internal hostnames in it.

## What it checks

| Scan | Tool | Finds |
|---|---|---|
| Secrets | [Gitleaks](https://github.com/gitleaks/gitleaks) | Keys, passwords, tokens, and `.env` files anywhere in the git history |
| Dependencies | [OSV-Scanner](https://github.com/google/osv-scanner) | Packages with known vulnerabilities, in every lockfile |
| Code | [Semgrep](https://github.com/semgrep/semgrep) | Insecure patterns in the source, including [our own rules](configs/semgrep/rules) for common AI-generated flaws |
| Dynamic | [OWASP ZAP](https://www.zaproxy.org/) | Missing headers, weak cookies, open CORS, and leaked errors in the running application |

All four tools are free and open source.

## Add it to a project

Create `.github/workflows/security.yml` in the project:

```yaml
name: Security

on:
  pull_request:
  push:
    branches: [main]
  schedule:
    - cron: "0 4 * * 1"

permissions:
  contents: read

jobs:
  security:
    uses: QuantumLogicsLabs/QuantumSecurity/.github/workflows/security.yml@main
    with:
      enforce: false
```

`enforce: false` only reports. Switch it to `true` when the existing findings
are fixed, and the scans start blocking pull requests. The full steps are in
[docs/adoption.md](docs/adoption.md).

## Scan a project on your own machine

With Docker running, from this repository:

```powershell
.\scripts\local-scan.ps1 -Project C:\path\to\project
```

## What is in this repository

| Path | Contents |
|---|---|
| [`.github/workflows/security.yml`](.github/workflows/security.yml) | Reusable workflow: secrets, dependencies, code |
| [`.github/workflows/dast.yml`](.github/workflows/dast.yml) | Reusable workflow: dynamic scan of a running application |
| [`configs/`](configs) | Shared rules for Gitleaks, Semgrep, and ZAP |
| [`scripts/`](scripts) | The scan scripts the workflows run, the local scan, and the self-test |
| [`templates/`](templates) | Files to copy into a project: workflows, Dependabot, AI assistant rules, pull request checklist, security policy |
| [`docs/`](docs) | Guides and policies |

## Guides

- [Adding the scans to a project](docs/adoption.md)
- [Security checklist](docs/checklist.md): what the scans cannot check
- [Local pentest guide](docs/pentest-guide.md): attacking your own project by hand
- [When a secret is leaked](docs/secret-rotation.md)
- [Severity and fix deadlines](docs/severity-policy.md)

## Changing the scans

Everything here runs on every project, so changes are tested before they merge.
The [self-test workflow](.github/workflows/self-test.yml) plants a known problem
for each scan and fails if a scan misses it.

- **Scanner versions** are pinned in [`scripts/install-tools.sh`](scripts/install-tools.sh)
  and [`scripts/local-scan.ps1`](scripts/local-scan.ps1). Update both together,
  including the checksums.
- **Semgrep rules** each need a test case in [`configs/semgrep/tests`](configs/semgrep/tests).
  Run the rule tests with:

  ```bash
  docker run --rm -v "${PWD}:/src" -w /src semgrep/semgrep:1.179.0 semgrep scan --test --config configs/semgrep/rules configs/semgrep/tests
  ```

- **Rule severity** decides what blocks. `ERROR` fails a pull request in an
  enforced project; `WARNING` is reported only. Add a new rule as `WARNING`
  first, and raise it once it has proved accurate.
