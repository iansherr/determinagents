# Data Flow Verify (observed-vs-theorized)

## Purpose

Trace a user-visible flow end-to-end **by executing it** rather than by reading source. The agent drives the UI (or invokes the API), captures real wire traffic at each layer, and produces a field round-trip table built from observed bytes — not theorized bytes.

The dominant failure mode this catches: **silent layer drift.** A field renamed in one layer but not another. A type that's `string` on the wire and `int` in the DB. A JSONB column whose hydration hook reshapes the data so the read path sees something different from what the write path stored. Static `DATA_FLOW_TRACE.md` *infers* these from code; this doc *observes* them.

## Relationship to DATA_FLOW_TRACE.md

| | `DATA_FLOW_TRACE.md` | `DATA_FLOW_VERIFY.md` (this doc) |
|---|---|---|
| Mode | Static source-trace | Agentic with execution capability |
| Inputs | Frontend code, handler code, schema | Running app + ability to drive it |
| Output | Inferred field round-trip table | Observed field round-trip table |
| False positives | Higher (inference can miss runtime transforms) | Lower (only observed drift reaches the report) |
| Best for | Quick understanding of flow shape | Validating critical / paid / regulated flows |

Run `DATA_FLOW_TRACE.md` first to map the flow's shape. Run this doc to verify the bits actually move that way.

## Mutating: yes (in disposable workspace)

This doc:
- Drives the UI (real clicks via Playwright/Puppeteer, or simulated)
- Issues real HTTP requests
- Inspects the database
- May insert test data
- Captures network traffic

All execution happens in a disposable workspace per the harness conventions in `specs/FORMAT.md`. The doc never touches production data.

## Prerequisites

Per `specs/FORMAT.md` harness conventions:

1. **Disposable workspace** — local dev env, containerized stack, or staging environment the user has confirmed is safe to drive
2. **App runs locally** (or on a reachable URL the user has authorized)
3. **AUDIT_CONTEXT.md `DATA_FLOW_VERIFY` section** configured — start command, test account credentials, network capture tool, DB inspection commands
4. **A specific flow target** — "save bookmark", "submit application", "update profile" — not "all flows"
5. **Browser automation available** if the flow has a UI surface (Playwright MCP, Puppeteer, Selenium, or equivalent)

If any prerequisite is missing, stop and surface that. The point of this doc is *observed* not *speculated*.

## Time estimate

Per flow; depends on flow complexity. Most of the time is in setup (auth, fixtures, network capture); the actual flow drive is fast. Use `--max-time=Xm` to bound.

## Output

`docs/reports/DATA_FLOW_VERIFY_<flow-slug>_<YYYY-MM-DD>.md`. Includes the observed field round-trip table, captured wire traffic, and DB inspection results. Per harness convention, raw captures go in `docs/reports/data-flow-artifacts/<report-name>/`.

---

## Phase 0: Discovery & setup

### 0.1 Workspace check

Per harness convention. Confirm disposable workspace explicitly.

### 0.2 Stack check

```bash
# Start command from AUDIT_CONTEXT
<start command>

# Wait for ready signal (health check, port open, log line)
curl -fsS <health-url> > /dev/null && echo "ready"
```

If the app doesn't start cleanly, stop and surface that — debugging the start environment is out of scope; the user fixes their dev env first.

### 0.3 Tool availability

```bash
# Browser automation
which playwright || npm ls @playwright/test 2>/dev/null
which puppeteer || npm ls puppeteer 2>/dev/null

# Network inspection
which mitmproxy
which tcpdump

# DB inspection (per AUDIT_CONTEXT)
psql --version
mysql --version
```

If browser automation is missing for a UI flow, the user can either install it or the agent operates in API-only mode (skip the UI-driven steps; start the trace at the network layer).

### 0.4 Auth setup

Most flows need a logged-in user. From AUDIT_CONTEXT, get the test account credentials. Authenticate once and persist the session (cookie jar / token in env) so each subsequent step doesn't re-auth and pollute the trace.

### 0.5 Read static DATA_FLOW_TRACE report (if exists)

If `docs/reports/DATA_FLOW_<flow-slug>_*.md` exists, read it. It carries the *theorized* round-trip table — this audit's job is to compare observed vs theorized and flag every divergence.

---

## Phase 1: Drive the flow

### 1.1 UI driver (if applicable)

Using the chosen browser-automation tool, perform the user action documented in the flow target. Capture:

- All network requests issued (URL, method, request body, headers — minus secrets)
- All network responses received (status, body, headers)
- Cookies set / cleared
- Console errors

Example with Playwright:

```typescript
const requests = [];
page.on('request', r => requests.push({
  url: r.url(), method: r.method(), body: r.postData(), headers: r.headers()
}));
const responses = [];
page.on('response', async r => responses.push({
  url: r.url(), status: r.status(), body: await r.text().catch(() => null)
}));

// drive the flow
await page.goto(<URL>);
await page.fill(<selector>, <value>);
await page.click(<submit selector>);
await page.waitForResponse(/* the expected backend call */);
```

### 1.2 API driver (if no UI)

```bash
# Capture from a curl invocation. Adapt to the flow.
curl -v -X POST <URL> \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @request.json \
  2>&1 | tee api-trace.log
```

### 1.3 Database snapshot

Before and after the action:

```bash
# Snapshot relevant tables before
<DB_INSPECT_CMD> "SELECT * FROM <table> WHERE ..." > before.txt

# (drive the flow)

# Snapshot after
<DB_INSPECT_CMD> "SELECT * FROM <table> WHERE ..." > after.txt
diff before.txt after.txt
```

This shows what *actually* changed in persistence — the ground truth for "did the write succeed and with what shape."

---

## Phase 2: Build the observed round-trip table

For each field the user submitted, fill in:

| UI form field | Request body key | DB column | DB stored value | Read response key | Status |
|---|---|---|---|---|---|
| `email` (input field name) | `email` (request JSON) | `users.email` (column) | `user@example.com` | `email` (response JSON) | OK |
| `companyName` | `company_name` | `users.company_name` | `"Acme"` | `company_name` | OK |
| `preferences.theme` | `preferences.theme` (camelCase) | `users.preferences` JSONB | `{"theme": "dark"}` | `preferences.theme` | **DRIFT** — shape changed: stored as snake_case but returned as camelCase |
| `signupSource` | (missing from request) | (column doesn't exist) | — | — | **DROPPED** — UI captured it, frontend never sent it |

Every row that's not `OK` is a finding. The status values:

- **OK** — round-trips correctly
- **DRIFT** — name or shape differs across layers (commonly: snake_case ↔ camelCase, JSONB hydration, type coercion)
- **DROPPED** — captured by UI, lost before persistence
- **PHANTOM** — read path returns a key that has no corresponding DB column (computed? cached? stale?)
- **TYPE_MISMATCH** — same key, different types (e.g., string in JSON, int in DB)

### 2.1 Field-level types

For each row, check both serialized type (in JSON) and stored type (in DB). Common silent issues:

- IDs as strings in JSON, integers in DB — works until ID > `2^53`
- Booleans as `0/1` in DB, `true/false` in JSON — works until something checks `=== true`
- Dates as strings vs timestamps — timezone bugs hide here
- Empty arrays as `[]` vs `null` — frontend may not handle both

Each silent type mismatch is a row in the table.

---

## Phase 3: Cache and re-read

### 3.1 Cold re-read

After the write, immediately re-read the resource via the read endpoint. Does the response contain the data just written, or stale?

```bash
# Re-read
curl -fsS <READ_URL> -H "Authorization: Bearer $TOKEN" | tee post-write-read.json

# Compare to the write request body
diff <(jq -S . request.json) <(jq -S . post-write-read.json)
```

### 3.2 Cache layer surface

If the AUDIT_CONTEXT lists cache layers (Redis, CDN, React Query cache, browser cache), inspect them:

- For each cache, did the write invalidate the relevant key?
- For each cache, does the next read hit the cache or the source?
- Race window: between the write commit and cache invalidation, what does a concurrent read see?

### 3.3 Cross-page consistency

If the flow is reflected in multiple UI surfaces (list view + detail view + admin panel), drive each and confirm consistency. List view often caches differently from detail view; this is a common drift vector.

---

## Phase 4: Triage & classify

For each row in the observed round-trip table marked non-OK:

| Severity | Criteria |
|----------|----------|
| **P0** | User-visible data loss (DROPPED on a critical field), wrong data persisted (TYPE_MISMATCH causes wrong DB value), or stale read after write (cache invalidation broken on a path users hit) |
| **P1** | Data persists correctly but read path returns stale or wrong shape; admin-only views diverge from user views; field exists in two layers but with different name and the mapping isn't documented |
| **P2** | DRIFT that works today but is fragile (works because nothing reads the field; would break if a future read does); JSONB shape undocumented |
| **P3** | Cosmetic drift (case mismatch in unused field; key present in response but no UI consumer) |

### 4.1 Compare against AUDIT_CONTEXT known-drift entries

Some drifts are intentional and documented (e.g., snake_case-in-DB / camelCase-in-API as a project convention). Don't re-flag these — see AUDIT_CONTEXT `DATA_FLOW_VERIFY` section "Known intentional drift."

### 4.2 Compare against the static DATA_FLOW_TRACE report

If a static trace existed, every drift this audit found that the static trace missed is doubly important — it's a category of bug the static analysis can't catch. Note these explicitly.

---

## Phase 5: Report

Per `specs/FORMAT.md` universal sections (severity rubric, next steps), plus:

- **Flow target** — what user action was driven
- **Environment** — branch, commit, dev/staging URL, browser/tool versions
- **Observed round-trip table** — the table from Phase 2
- **Cache behavior** — observations from Phase 3
- **Findings** — per-severity, with the artifacts directory link for each
- **Attempted but blocked** — if the flow rejected the agent's input due to validation/auth (positive signal — defense is working)
- **Patterns observed** — meta (e.g., "every JSONB field in this codebase has snake_case ↔ camelCase drift; consider a project-wide hydration convention")

Captured artifacts (request/response bodies, DB snapshots, screenshots) go in `docs/reports/data-flow-artifacts/<report-name>/`.

---

## Severity rubric (this audit)

See Phase 4. Briefly:

- **P0**: data lost, wrong, or stale on user-critical paths
- **P1**: drift between layers that's not documented
- **P2**: fragile drift that works today
- **P3**: cosmetic drift

Adopting the SECURITY_HUNT-style rubric: severity is by **observable defect**, not by speculative impact. Don't downgrade a DROPPED field because "the user probably doesn't notice" — they will, eventually, and the field is gone.

---

## Implementation rules

(Inherits the harness conventions from `specs/FORMAT.md`.)

- **One flow per session.** Multi-flow campaigns are multi-session.
- **Real network capture, real DB inspection.** No "I think the response would look like this" — observe and capture.
- **Test data, not real user data.** Use fixture accounts; never drive flows against production user records.
- **Tear down test data.** Whatever you create during the trace, delete or mark for cleanup. Otherwise the next session inherits noise.
- **Capture before you classify.** Save the raw request/response/DB snapshots first. Classification can be re-done from artifacts; observations cannot be re-collected after the workspace is gone.

---

## Anti-patterns

- **Speculative round-trip table.** That's `DATA_FLOW_TRACE.md`. Don't call it a verify.
- **Driving against production.** Even read-only flows can leak (auth tokens in capture, PII in artifacts). Disposable env, always.
- **Skipping the DB snapshot.** "I assume the write worked because the response was 200" is exactly the failure mode this audit exists to catch — handlers can return 200 and not write, or write the wrong thing.
- **One giant report covering 5 flows.** Per-flow scope; one report per session.

---

## Composition

- **Input from**: `DATA_FLOW_TRACE.md` (static map) — useful but not required
- **Output to**: `RESOLVE_FROM_REPORT.md` for fixes
- **Pair with**: `TESTING_CREATOR.md` Tier 1 (Adversarial) — turn DROPPED-field findings into a permanent test that submits the flow and asserts the field round-trips

The chain for data integrity assurance:

```
DATA_FLOW_TRACE → maps the flow shape (cheap)
DATA_FLOW_VERIFY (per critical flow) → observes real bytes
RESOLVE_FROM_REPORT → fixes findings
TESTING_CREATOR Tier 1 → adds permanent regression coverage
DATA_FLOW_VERIFY re-run → confirms clean
```
