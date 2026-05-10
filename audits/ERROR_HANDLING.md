# Error Handling Audit

## Purpose

Find errors that happen but nobody notices. Three failure modes:

1. **Swallowed**: caught and discarded (`.catch(() => {})`, bare `except: pass`).
2. **Logged-but-not-surfaced**: written to a log nobody reads while the user sees a blank screen or a generic spinner.
3. **Misclassified**: a 500 returned as a 200 with empty body, or a 404 treated as "no results."

The user-visible symptom is "the feature just doesn't work" with no error to grep for. This is the highest-leverage audit because almost every codebase has rich findings here.

## When to run

Anytime. Read-only. Especially after a "works in dev, mysteriously broken in prod" report, or when support tickets read "I clicked X and nothing happened."

## Time estimate

30–60 min.

## Output

`docs/reports/ERROR_HANDLING_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery

```bash
# Logging library / error handling library
grep -rln --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'logger|logrus|zap|winston|pino|structlog' . | grep -v node_modules | head -10

# Frontend error boundaries
grep -rln --include='*.tsx' --include='*.jsx' \
  -E 'componentDidCatch|ErrorBoundary|<Suspense' . | grep -v node_modules | head -10

# Toast / notification system
grep -rln --include='*.tsx' --include='*.jsx' --include='*.vue' \
  -E 'toast|notify|notification|snackbar' . | grep -v node_modules | head -10
```

Record: how errors should reach the user (toast component? error boundary? page-level error?).

---

## Phase 1: Swallowed Errors (Frontend)

### 1.1 Empty catches

```bash
# JS/TS
grep -rEn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  -E '\.catch\(\s*(\(\s*\)|\(\s*[a-zA-Z_]+\s*\))\s*=>\s*(\{\s*\}|null|undefined|\[\]|false|true|0)' \
  . | grep -v node_modules | grep -v '.compiled.'

# Empty catch blocks
grep -rEn -A2 --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  'catch\s*\(' . | grep -v node_modules | grep -B1 -A1 -E '^\s*\}'
```

### 1.2 Catch-and-fallback (silent degradation)

The pattern `.catch(() => defaultValue)` returns success-shaped data on failure, so the UI can't distinguish "no results" from "request failed."

```bash
grep -rEn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  -E '\.catch\([^)]+=>\s*(\[\]|\{\}|null|0|false)' . | grep -v node_modules
```

Each match: is the fallback distinguishable from a real empty result? If not — bug.

### 1.3 Promise without `.catch` or `await` without `try`

```bash
# Top-level awaits with no try wrapping
grep -rEn -B3 --include='*.ts' --include='*.tsx' \
  'await\s+(fetch|axios|api)' . | grep -v node_modules | head -50
```

For each, check whether it's inside a try/catch or a framework-level error boundary.

---

## Phase 2: Swallowed Errors (Backend)

### 2.1 Bare exceptions / discarded errors

```bash
# Python: bare except, except-pass, except Exception with no log
grep -rEn -A2 --include='*.py' \
  -E 'except(\s*:|\s+Exception\s*:|\s+\w+\s*:)' . | grep -v test \
  | grep -B1 -A2 -E '^\s*(pass|return\s*$|return None)'

# Go: discarded error
grep -rEn --include='*.go' \
  -E '_\s*[:=]\s*\w+.*\(' . | grep -v _test | head -50
# (false positives common — review manually for actual error returns being thrown away)

# JS/TS: try/catch with empty body
grep -rEn -A3 --include='*.ts' --include='*.js' \
  'catch\s*\(' . | grep -v node_modules | grep -B1 -A3 -E '^\s*\}'
```

### 2.2 Error returned as success

Handlers that catch an error and return 200 OK with an empty/default response. The frontend can't tell the call failed.

```bash
# Heuristic: catch followed by 200/JSON response with empty data
grep -rEn -A5 --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'except|catch\s*\(' . | grep -v test | grep -v node_modules \
  | grep -B5 -E '(c\.JSON\(200|res\.json\(\{|return jsonify)' | head -80
```

---

## Phase 3: Logged-but-not-surfaced

### 3.1 Server errors that log but return generic responses

For each 500-class handler path, verify:
- It logs with enough context to debug (request ID, user, params)
- It returns a structured error response (not just `"internal error"`)
- The frontend has a way to display it

```bash
grep -rEn -A3 --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E '(logger|log)\.(Error|error|Errorf)' . | grep -v test | grep -v node_modules | head -80
```

For each error log site: trace what response is sent. If response is `200` or generic-500, flag.

### 3.2 Errors logged client-side but no UI feedback

```bash
grep -rEn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  -E 'console\.(error|warn)\(' . | grep -v node_modules
```

For each: is there also a user-visible UI update? `console.error` alone is not error handling.

---

## Phase 4: UI Error States

### 4.1 Loading states without error states

For each component that fetches data, verify it has all three states: loading, error, success. The common gap is "loading" + "success" with no "error" — when the request fails, the spinner runs forever.

```bash
# Heuristic: components using a fetching hook
grep -rEn --include='*.tsx' --include='*.jsx' \
  -E 'useQuery|useSWR|useEffect.*fetch|useState.*loading' . | grep -v node_modules | head -50
```

For each, look at the rendering logic. Does it branch on `isError` / `error` / `failed`?

### 4.2 Error boundary coverage

```bash
grep -rEn --include='*.tsx' --include='*.jsx' \
  'ErrorBoundary|componentDidCatch' . | grep -v node_modules
```

Are error boundaries placed at route-level? Per-feature? If absent, an unhandled render error blanks the whole app.

### 4.3 Form validation feedback

For each `<form>`: when validation fails, where does the message appear? Inline next to the field, or only as a generic toast, or not at all?

---

## Phase 5: Misclassified errors

### 5.1 404 treated as empty

```bash
# Frontend treating non-2xx as empty array
grep -rEn -A3 --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  -E 'response\.ok|res\.status' . | grep -v node_modules | head -50
```

If the code does `if (!res.ok) return []` — flag. The user can't distinguish "no items" from "auth expired."

### 5.2 Network error treated as validation error

`fetch()` throws on network failure but resolves on HTTP 4xx/5xx. Code that handles only `.catch` misses HTTP errors; code that handles only `!response.ok` misses network errors. Both must be handled.

### 5.3 Timeouts

```bash
# Find configured timeouts (if any)
grep -rEn --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'timeout|deadline|AbortController|Timeout' . | grep -v node_modules | grep -v test | head -50
```

Outbound HTTP calls without a timeout = potential indefinite hang. Worth flagging especially for SSR / serverless contexts.

---

## Phase 6: Fault injection (mutating; opt-in)

This phase is **mutating** and **optional**. It moves error-handling auditing from "I think this catch swallows errors" (Phases 1–5) to "I observed this catch swallow a real error" (Phase 6). For codebases with build/run infrastructure, this catches the entire class of false negatives that static analysis can't.

Inherits the harness conventions from `specs/FORMAT.md` (disposable workspace, AUDIT_CONTEXT integration, verification loop, artifact capture).

### 6.1 Prerequisites

- Disposable workspace (per harness conventions)
- App runs locally; user has authorized fault injection against this environment
- AUDIT_CONTEXT.md `ERROR_HANDLING` section configured: start command, fault-injection tooling preference (mock service worker, Playwright route interception, Toxiproxy, network-namespace tools)

If prerequisites are missing, stop and report — do not skip silently to Phases 1–5 results, because the user invoked a harness phase expecting harness rigor.

### 6.2 Build the fault catalog

For each finding from Phases 1–3 that you'd like to verify, write a corresponding fault. Examples:

| Suspected pattern | Fault to inject | Observation |
|-------------------|-----------------|-------------|
| `.catch(() => [])` on a list fetch | Make the list endpoint return 500 | Does UI show error or empty state? |
| `await fetch()` with no try | Make the call reject (network error) | Does the page crash, hang, or surface? |
| Generic 500 error UI | Trigger 500 | Is the message specific enough to act on? |
| Logged-but-not-surfaced server error | Trigger the error path | Is it visible in the UI within reasonable time? |

### 6.3 Inject and observe

The mechanism depends on the project's stack and what the AUDIT_CONTEXT recommends:

**For SPA frontends** — Playwright route interception:

```typescript
await page.route('**/api/list', route => route.fulfill({
  status: 500,
  body: JSON.stringify({ error: 'simulated' }),
}));
// drive the UI; observe what user sees
```

**For Node services** — wrap the HTTP client with a fault layer (`nock`, `msw/node`).

**For Go/Python services** — Toxiproxy or a stub server replacing the real dependency.

**For external dependencies** (DB, Redis, Stripe) — bring the dependency to an unhealthy state in the disposable env (compose stop, iptables drop, mock 503).

For each fault: drive the user-facing path, capture what the user sees (screenshot, console log, error toast, full-page error, indefinite spinner, blank screen).

### 6.4 Classify outcomes

| Outcome observed | Severity escalation |
|------------------|---------------------|
| Indefinite spinner | P0 if user-critical, P1 otherwise |
| Blank screen / page crash | P0 if user-critical, P1 otherwise |
| Generic "something went wrong" with no recovery | P1 if path is reachable in normal use |
| Error toast that disappears, no inline indicator | P2 |
| Specific error message + retry affordance | OK — defense working |
| Action no-ops, UI shows success | P0 — silent corruption pattern |

The harness lets you distinguish P0-critical (UI lies about success) from P1-degraded (UI shows generic error) from OK (graceful handling). Static analysis can't distinguish these because they're behavioral, not structural.

### 6.5 Capture artifacts

Per harness convention: every confirmed finding includes a screenshot/recording at `docs/reports/error-handling-artifacts/<report-name>/<finding-N>/` plus the fault that triggered it. Stays reproducible after the disposable workspace is gone.

### 6.6 Attempted but blocked

Faults the system handled gracefully are positive signal — log them under "Attempted but blocked" in the report. Validates that error-handling investments are paying off.

---

## Severity rubric

| Severity | Criteria |
|----------|----------|
| **P0** | Silent failure on a user-facing critical path (auth, payment, save) |
| **P1** | Silent failure on a non-critical path; or critical path with generic error UI that obscures the cause |
| **P2** | Logged-but-not-surfaced on a path users will hit weekly; missing timeouts on external calls |
| **P3** | Missing log context; cosmetic error UI gaps |

Each finding should answer: **what does the user see when this fails?**

---

## Report template

Reports must also include the universal sections from `specs/FORMAT.md` — `## Severity rubric (this audit)` (copied verbatim from this doc's rubric) and `## Next steps` (paste-ready RESOLVE_FROM_REPORT invocation with this report's path filled in). Audit-specific structure below:

```markdown
# Error Handling Audit — <DATE>

## Summary
- Findings: X (P0: X, P1: X, P2: X, P3: X)
- Phases run: ...

## Top recurring patterns
1. <e.g., ".catch(() => []) on list endpoints — found in N places">
2. ...

## P0 — Silent failures on critical paths
| Location | Pattern | What user sees | Suggested fix |
|---|---|---|---|
| `<file>:<line>` | `.catch(() => null)` after fetch | Spinner runs forever | Throw, show error toast |

## P1 — ...

## P2 — ...

## P3 — ...

## Recommendations
1. ...
```
