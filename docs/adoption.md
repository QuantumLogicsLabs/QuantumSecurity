# Adding the security scans to a project

This takes about ten minutes per project. Nothing is installed in the project;
it only gains two or three small files.

## 1. Add the workflow

Copy [`templates/workflows/security.yml`](../templates/workflows/security.yml) to
`.github/workflows/security.yml` in the project and push it.

From then on, every pull request, every push to the main branch, and a weekly
schedule run three scans:

| Scan | What it checks | What blocks |
|---|---|---|
| secrets | The whole git history, for keys, passwords, tokens, and committed `.env` files | Any secret |
| dependencies | Every lockfile, in any subfolder, for packages with known vulnerabilities | CVSS 7.0 or higher |
| code | The source code, for insecure patterns | Findings with severity ERROR |

Results appear in the pull request's checks. The full reports are attached to
the workflow run as artifacts.

## 2. Start in report-only mode

The template sets `enforce: false`. In this mode the scans report what they find
but never fail, so the team can see the backlog without being blocked by it.

Work through the findings in this order:

1. **Secrets.** Treat every one as already stolen. Follow [secret-rotation.md](secret-rotation.md).
2. **Dependencies.** Add [`templates/dependabot.yml`](../templates/dependabot.yml) to the project and merge the upgrade pull requests it opens.
3. **Code.** Fix the blocking findings first, then the warnings.

## 3. Turn on enforcement

When the scans are clean:

1. Change `enforce: false` to `enforce: true` in the project's workflow file.
2. In the project on GitHub, open **Settings > Branches**, protect the main
   branch, and require these status checks: `security / secrets`,
   `security / dependencies`, and `security / code`.

A pull request that introduces a blocking finding can no longer be merged.

## 4. Add the supporting files

| File | Copy to | Purpose |
|---|---|---|
| [`templates/AI_SECURITY_RULES.md`](../templates/AI_SECURITY_RULES.md) | Paste into `CLAUDE.md`, `AGENTS.md`, or `.cursorrules` | Makes AI assistants write secure code in the first place |
| [`templates/PULL_REQUEST_TEMPLATE.md`](../templates/PULL_REQUEST_TEMPLATE.md) | `.github/PULL_REQUEST_TEMPLATE.md` | Puts the review checklist in front of every reviewer |
| [`templates/SECURITY.md`](../templates/SECURITY.md) | `SECURITY.md` | Tells people how to report a vulnerability privately |
| [`templates/pre-commit-config.yaml`](../templates/pre-commit-config.yaml) | `.pre-commit-config.yaml` (optional) | Stops a secret on the developer's machine, before it is committed |

## 5. Add the dynamic scan (web applications)

The three scans above read files. The dynamic scan tests the running
application from the outside with OWASP ZAP and finds what only shows up at
run time: missing security headers, weak cookies, open CORS, leaked errors.

Copy [`templates/workflows/dast.yml`](../templates/workflows/dast.yml) to
`.github/workflows/dast.yml` and set two values:

- `target-url`: where the application answers.
- `start-command`: how to start it inside the runner, for example
  `docker compose up -d`. Delete this line if `target-url` is a staging site
  that is already running.

If the application needs environment variables to start, give it test values in
its compose file. Do not use production credentials for a scan.

## When a finding is wrong or cannot be fixed yet

Suppress one finding at a time, in the project, with a written reason. Never
turn a whole scan off.

**Secrets.** After the secret is rotated, add its fingerprint to a
`.gitleaksignore` file in the project root. The scan log prints the fingerprint
for every finding.

**Dependencies.** Create `osv-scanner.toml` next to the lockfile:

```toml
[[IgnoredVulns]]
id = "GHSA-xxxx-xxxx-xxxx"
ignoreUntil = 2026-12-31
reason = "No fixed version yet. The affected function is never called."
```

Always set `ignoreUntil`, so the finding comes back for another look.

**Code.** Put a comment on the line above the finding:

```js
// nosemgrep: quantum-cors-allow-all -- public read-only API, no cookies or credentials
app.use(cors());
```

If one of our own rules is wrong for everyone, fix the rule in
[`configs/semgrep/rules`](../configs/semgrep/rules) instead.

## If the workflow does not start

- **"Workflow is not allowed" or the run never appears.** The organisation's
  Actions settings may restrict which actions can run. Allow actions created by
  GitHub and `zaproxy/action-baseline`.
- **A warning says a `package.json` has no lockfile.** The dependency scan reads
  lockfiles. Run `npm install` in that folder and commit `package-lock.json`.
