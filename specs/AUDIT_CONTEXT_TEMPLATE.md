# Audit Context — <PROJECT NAME>

> Project-specific overlay for the universal audits in `${DETERMINAGENTS_HOME:-$HOME/.determinagents}/`.
> Read this file before running any audit. See `BOOTSTRAP.md` for what belongs here.
>
> **Last reviewed:** YYYY-MM-DD

---

## Global

### Auth model

> 1–3 sentences. Where does authn happen? Where does authz happen? Opt-in or opt-out per route?
> Anything that changes how a security or data-flow audit should treat "unprotected" routes.

_Example:_ Auth is enforced by a middleware applied per-route (opt-in). Any new route is unauthenticated by default — treat as P1 unless explicitly meant to be public.

### Conventions

> Project-specific patterns that affect grep / discovery. JSONB hydration via `AfterFind`, custom RPC layer, code-generation directories, monorepo workspace layout, etc.

_Example:_ JSONB columns are hydrated via GORM `AfterFind` hooks. A column's app-level shape may differ from its DB shape — always check both.

### Archived / ignore paths

> Directories the agent should not audit. Past code kept for reference, vendor copies, generated output that's checked in.

```
.archive/
backups/
services/legacy-foo/
site/source/assets/js/*.compiled.js
```

### Severity calibrations

> Where this project's P-levels differ from the universal rubric, and why.

_Example:_ Admin-panel gaps are P1, not P0. Admins know to report breakage out-of-band, and these endpoints are never hit by end users.

### Recent incidents (worth knowing)

| Date | Incident | Pattern to watch | Reference |
|---|---|---|---|
| 2026-04 | Phantom admin endpoints | `.catch(() => fallback)` masking 404s | `docs/operations/ADMIN_PANEL_FIXING_GUIDE.md` |

---

## STUB_AND_COMPLETENESS

### Known stub files
> Files known to contain stubs. Audit verifies whether they're still stubs.

- `<path>` — <what's stubbed and why>

### Known phantom endpoints (intentional)
> URLs the frontend calls that have no backend handler **on purpose** (e.g., feature flag, planned). Don't re-flag these as P0.

- `POST /api/x/y` — planned for Q3, see issue #123

### Known dead-code zones
> Directories where dead code accumulates, OR where what looks dead is actually live (e.g., dynamically loaded).

---

## SECURITY_PENTEST

### Auth model exceptions
> Routes that are intentionally unauthenticated despite looking sensitive. Justify each.

- `GET /api/healthz` — public by design, returns no PII

### Known false-positives
> Patterns that match a security-grep but are actually safe.

- `fmt.Sprintf` SQL builder in `services/foo/migrate.go` — runs only at startup with hardcoded args

### Out-of-scope
> Surfaces this audit should not cover (e.g., "third-party iframe is owned by vendor X, audited separately").

### Sensitive paths (extra scrutiny)
> Where the prior probability of vulnerabilities is highest, based on past findings.

---

## DATA_FLOW_TRACE

### Known JSONB shapes
> JSONB columns and their canonical shape. Useful when checking field round-trip.

| Column | Canonical shape | Hydration hook |
|---|---|---|
| `users.preferences` | `{theme, locale, notifications:{...}}` | `AfterFind` in `models/user.go` |

### Cache invalidation rules
> Caches in the path that need explicit busting. If you trace a flow that writes to one of these tables, also verify the cache is invalidated.

| Table | Cache key | Invalidation |
|---|---|---|

### Common drift points
> Past flows where a field name drifted between layers. Check first.

---

## ERROR_HANDLING

### Approved silent fallbacks
> Cases where `.catch(() => fallback)` is intentional (telemetry calls, optional features). Don't re-flag.

- `services/analytics/*` — tracking calls fall back silently by design

### Known unsurfaced-error hot spots
> Areas where errors are known to be swallowed but the fix is non-trivial. Track but don't re-report.

---

## TEST_GAPS

### Critical paths (project's own list)
> The user-facing paths this project considers most critical. The audit measures coverage against this list.

1. ...
2. ...

### Acknowledged untested areas
> Paths the team knows are untested and has chosen not to test. Don't re-flag.

### Test framework quirks
> Patterns that affect coverage interpretation (e.g., "coverage tool excludes generated code in `gen/`").

---

## DOCS_DRIFT

### Authoritative docs (verify on every run)
> Docs the team treats as load-bearing. Drift here is P0/P1.

- `README.md` — setup section
- `START_HERE.md` — onboarding
- `docs/operations/RUNBOOK.md`

### Known archive locations
> Where stale docs live (so the audit doesn't flag them).

- `docs/reports/.archive/`

---

## UX_DESIGN_AUDIT

### DESIGN.md location
> If non-standard.

### Allowed token deviations
> Places where deviation from DESIGN.md tokens is intentional (third-party widgets, legacy pages mid-migration).

- `site/legacy/*` — pre-token CSS, scheduled for migration in Q3

### Project-specific token names
> If this project uses non-standard variable names (`--brand-primary` vs `--color-primary`), note the mapping.

---

## Notes for the agent

- An empty section means "no special knowledge." Run the audit generically.
- If you discover a pattern during an audit that would belong here, propose an addition (see `BOOTSTRAP.md` warm-overlay mode).
- Do not duplicate content that lives in `ARCHITECTURE.md`, `START_HERE.md`, `CONTRIBUTING.md`, or the universal audit docs. Link instead.

## TEST_VERIFICATION
- Preferred simulation stack (e.g., Python + Docker Compose)
- Known non-idempotent setup steps to skip or fix
