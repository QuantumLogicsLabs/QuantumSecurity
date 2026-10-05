<!--
Paste everything below this comment into the file your AI coding assistant reads
in the project: CLAUDE.md, AGENTS.md, .cursorrules, or .github/copilot-instructions.md.
-->

## Security rules

Apply these rules to every change in this project. If a request conflicts with
one of them, say so and propose a safe alternative. Do not quietly break the rule.

### Secrets

- Never write a real key, password, token, or connection string in code, tests, comments, or documentation. Read secrets from environment variables.
- Never give a secret a fallback value such as `process.env.JWT_SECRET || "secret"`. Stop at startup when a required variable is missing.
- Never commit `.env`. Keep `.env.example` up to date, with placeholder values only.
- Never log secrets, tokens, passwords, or full request bodies.

### Authentication and sessions

- Hash passwords with bcrypt (12 rounds) or argon2. Never store or compare them in plain text.
- Give every token an expiry. Access tokens last minutes, not days.
- Set auth cookies with `httpOnly: true`, `secure: true`, and `sameSite`.
- Rate-limit login, signup, password reset, and OTP endpoints.
- Return the same error for "unknown user" and "wrong password".

### Authorization

- Every endpoint that is not public checks who the caller is. Add the check when you add the route.
- Every read, update, and delete of a record checks that the record belongs to the caller. An ID in the URL or body is never proof of ownership.
- Decide roles and permissions on the server, from the session or token. Never from a field the client sends.

### Input and data

- Validate every request body, query, and URL parameter against a schema (Zod, Joi, Pydantic) before using it.
- Never pass `req.body` or `req.query` to a database call as it is. Pick the allowed fields by name.
- Convert values to the expected type before they go into a query, so an object such as `{"$ne": null}` cannot become a query operator.
- Build SQL with parameters. Never by joining strings.
- Never build a shell command, file path, or URL to fetch from user input without checking it against a list of allowed values.
- Escape output. Do not use `dangerouslySetInnerHTML`, `innerHTML`, or `v-html` with user content.

### File uploads

- Limit the file size and the number of files.
- Allow file types from a fixed list, and check the content, not only the extension.
- Store files under a name the server generates, outside the folder that serves code.
- Never serve an uploaded file in a way that lets the browser run it as a page or script.

### Configuration

- CORS lists the exact origins that may call the API. Never `*`, and never a reflected origin together with credentials.
- Send security headers (use `helmet` in Express).
- Error responses give a generic message. Stack traces and database errors go to the server log only.
- Debug mode, verbose errors, and API documentation routes are off in production.

### Dependencies

- Add a dependency only when it is needed. Prefer packages that are widely used and maintained.
- Check that a package name is real and spelled correctly before installing it. Do not install a package only because it was suggested.
- Commit the lockfile.

### Before finishing

- State which of these rules the change touches and how it meets them.
- Point out anything in the surrounding code that already breaks a rule, even if it is outside the task.
