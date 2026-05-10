# End-to-End Data Flow Trace

## Purpose

Pick a user-visible action (e.g., "save bookmark", "submit application", "update profile") and trace its data end-to-end: UI → network → gateway → handler → DB → response → re-render. Find the layer where the path silently breaks, drops fields, mistypes IDs, or reads stale state.

This audit is a microscope, not a survey. One flow per run. Run it on multiple flows to build coverage.

## When to run

After a feature ships, after a "works in dev but not prod" report, before extracting a service, or whenever the stack feels like a black box.


**Model tier**: `default`

## Time estimate

30–60 min per flow.

## Output

`docs/reports/DATA_FLOW_<flow-name>_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery & Flow Selection

Pick **one** user action. The best candidates are state-changing actions visible in the UI — bookmarks, submissions, settings updates, status transitions.

```bash
# Identify candidate flows from frontend forms / mutations
grep -rEn --include='*.tsx' --include='*.jsx' --include='*.vue' \
  -E '<form|onSubmit|useMutation|fetch\(.*POST|fetch\(.*PUT' . | grep -v node_modules | head -30
```

Choose one. Record:
- **Action**: what the user does (click "Save Bookmark")
- **Trigger file:line**: where the click handler lives
- **Expected outcome**: what the UI should look like after success

---

## Phase 1: UI Layer

### 1.1 Trigger to request

Find the click/submit handler. Trace how it builds the request body.

Record:
- File:line of the handler
- Body shape (every field name and type)
- Headers set explicitly (Content-Type, Authorization, CSRF token)
- URL pattern with method

### 1.2 Optimistic UI vs. server confirmation

Does the UI update immediately and roll back on failure, or wait for server response? Either is fine, but document which.

Look for: `setState` before `await`, React Query `onMutate`, manual cache patching.

### 1.3 Error handling at the call site

```bash
# Find .catch handlers near the call
grep -rEn -A5 --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
  'fetch\(.*<URL_FROM_1.1>' . | head -50
```

Classify:
- **Surfaced**: user sees an error toast/message with detail
- **Generic**: "something went wrong" with no detail
- **Swallowed**: `.catch(() => {})` or `.catch(fallback)` — silent failure (a bug)

---

## Phase 2: Network Layer

### 2.1 Gateway / proxy rewrites

```bash
find . \( -name 'nginx.conf*' -o -name '*ingress*.yaml' -o -name 'Caddyfile' \
  -o -name 'vercel.json' -o -name 'netlify.toml' -o -name '_redirects' \) 2>/dev/null
```

For the URL from Phase 1, find every rewrite/proxy_pass that touches it. Record the URL path *as the backend sees it* (after rewrites).

### 2.2 Auth wrapping

Does the gateway add/strip headers? Does an auth-middleware service sit in the path? Record the request shape at every hop.

---

## Phase 3: Handler Layer

### 3.1 Locate the handler

Use the URL from Phase 2.1 to find the registered route, then the handler function.

### 3.2 Input parsing

Record:
- How the body is decoded (struct, dataclass, plain dict)
- Every field that's parsed
- Every field that's silently dropped (parsed body has fewer fields than UI sent)
- Type coercions (string → int, especially for IDs)

### 3.3 Authorization

Does the handler verify the current user owns/can-access the resource? Or does it trust the ID from the request body?

### 3.4 Validation

What's validated? What isn't? Empty strings, nulls, oversized inputs, malformed enums?

### 3.5 The persistence call

Find the SQL / ORM call.

```bash
# Trace from handler — adjust per language
grep -rEn --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'INSERT|UPDATE|\.create\(|\.save\(|\.update\(' . | grep -v test | grep -v node_modules
```

Record:
- Table name
- Columns written
- JSON/JSONB columns and what shape goes into them
- Whether `updated_at`/audit fields are set

---

## Phase 4: Database Layer

### 4.1 Schema check

```bash
# Find migrations or schema definitions
find . \( -path '*/migration*' -o -path '*/migrate*' -o -name '*.sql' -o -name 'schema.rb' \
  -o -name 'schema.prisma' \) -not -path '*/node_modules/*' | head -20
```

For the table from 3.5, list every column with its type and nullability. Cross-check against the handler:

- Every column the handler writes — does it exist with the right type?
- Every NOT NULL column — does the handler always set it?
- JSONB columns — what keys does the handler put in vs. what keys does the read path expect?

### 4.2 Indexes

Are there indexes on the columns this flow filters/joins on? Missing indexes don't cause correctness bugs but cause silent slowness that masquerades as "the app feels laggy."

### 4.3 Constraints & cascades

Foreign keys, ON DELETE behavior, unique constraints. If the user repeats this action, does the DB reject it or duplicate it?

---

## Phase 5: Read Path / Response

### 5.1 The read query

After the write, the UI reads back state (either from the response or a follow-up GET). Find the read handler.

### 5.2 Field round-trip

Every field the user submitted: does it come back through the read path? At what name? With what type? JSON serialization name vs. DB column name vs. UI field name — these drift constantly.

Make a 4-column table:

| UI form field | Request body key | DB column | Response JSON key |
|---|---|---|---|
| ... | ... | ... | ... |

Mismatches in this table are the most common silent-failure cause.

### 5.3 JSONB hydration

If the column is JSONB, how is it deserialized on read? Is there a hook (AfterFind/`@property`/getter) that re-shapes it? Does the UI expect the post-hook shape or the raw shape?

---

## Phase 6: Caching / Sync

```bash
# Caches and invalidations
grep -rEn --include='*.go' --include='*.py' --include='*.ts' --include='*.js' \
  -E 'cache|Redis|memcached|invalidate|revalidate|queryClient\.' . \
  | grep -v node_modules | grep -v test | head -50
```

For this flow:
- What cache layers exist (CDN, server cache, React Query cache, browser cache)?
- Is the cache invalidated on write, or does it serve stale data until TTL?

---

## Severity rubric

Per finding, classify the **layer break**:

| Severity | Criteria |
|----------|----------|
| **P0 — Broken** | Flow fails end-to-end for users (data lost, error, blank screen) |
| **P1 — Degraded** | Flow appears to work but data is wrong, stale, or partial |
| **P2 — Fragile** | Flow works today but a small upstream change would break it (type confusion, undocumented JSON shape) |
| **P3 — Cosmetic** | Drift that doesn't affect behavior (unused field, duplicate parse) |

---

## Report template

Reports must also include the universal sections from `specs/FORMAT.md` — `## Severity rubric (this audit)` (copied verbatim from this doc's rubric) and `## Next steps` (paste-ready RESOLVE_FROM_REPORT invocation with this report's path filled in). Audit-specific structure below:

```markdown
# Data Flow Trace: <Flow Name> — <DATE>

## Summary
- Flow: <user action description>
- Status: PASS / DEGRADED / BROKEN
- Findings: X (P0: X, P1: X, P2: X, P3: X)

## Path map
1. UI: `<file>:<line>` — `<component>.<handler>`
2. Network: `<URL>` → (rewrite: `<rewritten URL>`) → `<service>`
3. Handler: `<file>:<line>` — `<func>`
4. DB: `<table>` — INSERT into `<columns>`
5. Read: `<file>:<line>` — `<func>` reads from `<table>` via `<query>`
6. Response: `<JSON shape>`

## Field round-trip table
| UI field | Request key | DB column | Response key | Status |
|---|---|---|---|---|
| ... | ... | ... | ... | OK / DRIFT / DROP |

## Findings
### P0 — ...
- **Layer:** UI / Network / Handler / DB / Read / Cache
- **Issue:** ...
- **Evidence:** `<file>:<line>` ...
- **Suggested fix:** ...

## Patterns observed
<root cause — e.g., "JSONB column stores camelCase from Go, read path expects
snake_case in Python; works for the new field because nothing reads it yet.">

## Recommendations
1. ...
```
