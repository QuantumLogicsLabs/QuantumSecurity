# When a secret is leaked

A secret that reached GitHub must be treated as stolen, even if it was there for
a minute and even if the repository is private. Automated scrapers find new keys
on public repositories within minutes.

Deleting the line, or the file, does not help. The secret stays in the git
history, in forks, and in any clone made in the meantime.

## What to do, in order

### 1. Revoke the secret

Do this first. It is the only step that actually ends the exposure.

| Secret | Where to replace it |
|---|---|
| Database password or connection string | The database provider's console (for MongoDB Atlas: Database Access). Change the user's password. |
| JWT or session secret | Generate a new random value. All users are logged out; that is expected. |
| Third-party API key (payment, email, AI, storage) | The provider's dashboard. Revoke the old key and create a new one. |
| OAuth client secret | The provider's developer console. Regenerate it. |
| Cloud credentials | The cloud console. Deactivate the key, then delete it. |

Generate a new random secret with:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

### 2. Deploy the new value

Put the new secret in the hosting platform's environment settings, never in the
repository, and redeploy.

### 3. Check for misuse

Look at the provider's logs for the time the secret was exposed: database
access from unknown addresses, unexpected API usage or charges, new users or
keys that nobody on the team created. If you find any, tell the project owner
straight away.

### 4. Stop it from coming back

- Remove the secret from the code and read it from an environment variable.
- Make sure `.env` is listed in `.gitignore`.
- Add the placeholder to `.env.example`.

### 5. Clear the scan finding

The old value is still in the history, so the secrets scan keeps reporting it.
Now that the secret is dead, record that: copy the `Fingerprint` line from the
scan log into a `.gitleaksignore` file in the project root, one per line, and
commit it.

Only do this after step 1. An ignored secret that still works is the worst case:
the scan is silent and the key is live.

## Do I need to rewrite the git history?

Usually not. Once the secret is revoked, the old value in the history is
harmless. Rewriting history breaks every clone and open pull request, and does
not reach forks or copies that already exist.

Rewrite it only when the value cannot be revoked, such as personal data or a
private key that is also used elsewhere. Use
[git-filter-repo](https://github.com/newren/git-filter-repo) and coordinate
with everyone who has a clone.
