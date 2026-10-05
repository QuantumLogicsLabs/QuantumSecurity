# Severity and fix deadlines

One scale for every finding, whether it comes from a scan, a pentest, or an
outside report.

## Severity

| Severity | Meaning | Examples |
|---|---|---|
| Critical | An outsider can take over accounts, read or destroy the data of all users, or run code on the server. No login needed, or any login is enough. | A live secret in a public repository. Login bypass. An admin endpoint with no check. Remote code execution through a dependency. |
| High | A logged-in user can reach data or actions that belong to others, or an outsider can seriously harm some users. | Reading another user's records by changing an ID. Stored cross-site scripting. Unlimited file upload. A dependency with CVSS 7.0 or higher that the code actually uses. |
| Medium | A weakness that needs unusual conditions or a second flaw to exploit. | No rate limit on login. Tokens that never expire. Open CORS without credentials. Stack traces in responses. |
| Low | A hardening gap with little direct impact. | A missing security header. Version numbers in response headers. |

When unsure between two levels, pick the higher one and let the fix discussion lower it.

## Deadlines

Counted from the moment the finding is reported.

| Severity | Fix deployed within | Until then |
|---|---|---|
| Critical | 24 hours | Stop other work. Take the feature offline if it cannot be fixed at once. |
| High | 7 days | Blocks the next release. |
| Medium | 30 days | Planned into normal work. |
| Low | 90 days | Fixed when the code is next touched. |

## How the scans map to this

| Scan result | Severity |
|---|---|
| Any secret | Critical until it is revoked |
| Dependency with CVSS 9.0 or higher | Critical |
| Dependency with CVSS 7.0 to 8.9 | High |
| Semgrep finding with severity ERROR | High, unless review shows otherwise |
| Semgrep finding with severity WARNING | Medium |
| ZAP alert marked FAIL | High |
| ZAP warning | Low to Medium |

## Tracking

- Each finding gets an owner and a due date from the table above.
- Findings that are not fixed yet are tracked privately, not in a public issue.
- Once a fix is deployed, the person who reported the finding confirms it.

## Exceptions

A finding may stay open past its deadline only if the project owner agrees in
writing, with a reason and a new date. In the scans, that means a suppression
with a reason and an expiry, as described in [adoption.md](adoption.md). A
suppression with no reason is treated as a finding itself.
