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

## DATA_FLOW_VERIFY

### Stack start command

> How does the user start the application stack for verification work?

_Example:_ `docker compose -f deployments/docker/local-dev/docker-compose.yml up -d`

### Base URL

> Where the running app is reachable for the agent to drive.

_Example:_ `http://localhost:8080` (local), `https://staging.example.com` (staging — require explicit per-session approval)

### Test account credentials

> Reference (do NOT inline credentials in this overlay if the repo is public).

_Example:_ See `docs/operations/TEST_ACCOUNTS.md` for personas (admin, paid, free, banned).

### Network capture / browser tooling preference

> Which tool to use for driving the UI and capturing traffic.

_Example:_ Playwright MCP for UI, curl for API-only flows. mitmproxy if cross-cutting capture is needed.

### DB inspection commands

> How the agent inspects persistence to verify writes.

```
# Examples:
psql -h localhost -U postgres -d <dbname> -c "<query>"
redis-cli GET <key>
```

### Known intentional drift

> Drifts that are project conventions, not bugs. Do not re-flag these.

_Example:_ All API responses use camelCase; all DB columns use snake_case. The conversion happens in `services/foo/internal/serialize.go` AfterFind hook.

### Known cache layers (invalidation contract)

| Layer | Key pattern | Invalidation trigger |
|---|---|---|

---

## ERROR_HANDLING (Phase 6 fault injection)

### Fault-injection tooling preference

> How the agent injects faults to verify error paths.

_Example:_ Playwright `page.route` for SPA frontend; `nock` for Node services; `Toxiproxy` for inter-service flakiness.

### Approved fault scenarios

> Faults the user pre-authorizes for the disposable workspace. Scope this carefully — denial-of-service patterns may need explicit per-session approval.

_Example:_ 5xx responses on any internal API; 503 on Stripe; 30s delay on Redis. Do NOT bring DB completely down without per-session approval.

### Approved silent fallbacks (also see top-level ERROR_HANDLING)

> Cases where graceful degradation is intentional. Verified-OK responses to faults here are the desired behavior.

---

## STUB_AND_COMPLETENESS (Phase 6 endpoint verification)

### Probe base URL

> Where suspected phantom endpoints get probed.

_Example:_ Same as DATA_FLOW_VERIFY base URL.

### Test account for probing

> Which account to use. Often a low-privilege user; for admin endpoints, a separate admin probe account.

### Intentionally-unimplemented endpoints (do not flag as P0)

> URLs that intentionally 404 or 501 (planned features, deprecated routes scheduled for removal). Phase 6 will see these as confirmed-phantom; mark them P2 (planned) rather than P0.

_Example:_ `POST /api/v2/billing` — planned for Q3 2026, see issue #1234

---

## SECURITY_HUNT

### Build / test commands

> Required. SECURITY_HUNT cannot run without these.

```
build:    <command>            # e.g., cargo build --release
test:     <command>            # e.g., cargo test
asan:     <command or flags>   # e.g., RUSTFLAGS="-Z sanitizer=address" cargo test
ubsan:    <command or flags>
tsan:     <command or flags>   # if applicable
fuzz:     <harness path>       # if a fuzzing harness exists
```

### Disposable workspace convention

> How does the user typically create a disposable workspace for security work?

_Example:_ `git worktree add ../<repo>-hunt origin/main` followed by container build.

### Trust boundaries in this codebase

> Where attacker-controlled input meets privileged code. Highest-value targets for SECURITY_HUNT.

### Sensitive paths (elevated severity)

> Paths where findings deserve elevated severity treatment, beyond the universal P-rubric.

### Known-blocked attack patterns (do not re-attempt)

> Architectural defenses that already prevent certain bug classes. SECURITY_HUNT logs attempts that target these as "Attempted but blocked" rather than wasting cycles.

_Example:_ Prototype freezing on parent-process objects prevents prototype-pollution sandbox escapes — do not re-explore this vector.

### Past confirmed bugs in this target (dedup input)

| Date | Bug class | Target | Reference |
|---|---|---|---|

---

## TEST_VERIFICATION
- Preferred simulation stack (e.g., Python + Docker Compose)
- Known non-idempotent setup steps to skip or fix
