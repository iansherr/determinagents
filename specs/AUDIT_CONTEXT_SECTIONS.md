# AUDIT_CONTEXT Sections Catalog

Audit-specific sections for `docs/determinagents/AUDIT_CONTEXT.md`. Copy a section into AUDIT_CONTEXT only when you have something to put in it. An empty section is noise; a section that grew from a real audit run is signal.

The minimal template at `specs/AUDIT_CONTEXT_TEMPLATE.md` ships with Global only. This file is the catalog of sections you can layer on top.

For the warm-overlay workflow that adds sections after an audit run, see `specs/BOOTSTRAP.md`.

---

## STUB_AND_COMPLETENESS

### Known stub files
> Files known to contain stubs. Audit verifies whether they're still stubs.

- `<path>` — <what's stubbed and why>

### Known phantom endpoints (intentional)
> URLs the frontend calls that have no backend handler **on purpose**. Don't re-flag.

- `POST /api/x/y` — planned for Q3, see issue #123

### Known dead-code zones
> Directories where dead code accumulates, OR where what looks dead is actually live (e.g., dynamically loaded).

---

## STUB_AND_COMPLETENESS (Phase 6 endpoint verification)

### Probe base URL
> Where suspected phantom endpoints get probed.

### Test account for probing
> Which account to use. Often a low-privilege user; for admin endpoints, a separate admin probe account.

### Intentionally-unimplemented endpoints (do not flag as P0)
> URLs that intentionally 404 or 501 (planned features, deprecated routes scheduled for removal). Mark P2 (planned) rather than P0.

- `POST /api/v2/billing` — planned for Q3 2026, see issue #1234

---

## SECURITY_PENTEST

### Auth model exceptions
> Routes intentionally unauthenticated despite looking sensitive. Justify each.

- `GET /api/healthz` — public by design, returns no PII

### Known false-positives
> Patterns that match a security-grep but are actually safe.

- `fmt.Sprintf` SQL builder in `services/foo/migrate.go` — runs only at startup with hardcoded args

### Out-of-scope
> Surfaces this audit should not cover.

### Sensitive paths (extra scrutiny)
> Where the prior probability of vulnerabilities is highest, based on past findings.

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
_Example:_ `git worktree add ../<repo>-hunt origin/main` followed by container build.

### Trust boundaries in this codebase
> Where attacker-controlled input meets privileged code. Highest-value targets for SECURITY_HUNT.

### Sensitive paths (elevated severity)
> Paths where findings deserve elevated severity treatment.

### Known-blocked attack patterns (do not re-attempt)
> Architectural defenses that prevent certain bug classes. SECURITY_HUNT logs attempts that target these as "Attempted but blocked" rather than wasting cycles.

_Example:_ Prototype freezing on parent-process objects prevents prototype-pollution sandbox escapes.

### Past confirmed bugs in this target (dedup input)

| Date | Bug class | Target | Reference |
|---|---|---|---|

---

## DATA_FLOW_TRACE

### Known JSONB shapes

| Column | Hydration hook | Notes |
|---|---|---|
| `users.preferences` | `AfterFind` in `models/user.go` | snake_case in DB, camelCase after hook |

### Cache invalidation rules

| Table | Cache key | Invalidation trigger |
|---|---|---|

### Common drift points (verified historical)
> Past flows where a field name drifted between layers. Check first.

---

## DATA_FLOW_VERIFY

### Stack start command
> How to start the application stack for verification work.

_Example:_ `docker compose -f deployments/docker/local-dev/docker-compose.yml up -d`

### Base URL
> Where the running app is reachable for the agent to drive.

_Example:_ `http://localhost:8080` (local), `https://staging.example.com` (staging — require explicit per-session approval)

### Test account credentials reference
> Reference (do NOT inline credentials in this overlay if the repo is public).

_Example:_ See `docs/operations/TEST_ACCOUNTS.md` for personas (admin, paid, free).

### Network capture / browser tooling preference
> Which tool to use for driving the UI and capturing traffic.

_Example:_ Playwright MCP for UI, curl for API-only flows.

### DB inspection commands

```
psql -h localhost -U postgres -d <dbname> -c "<query>"
redis-cli GET <key>
```

### Known intentional drift
> Drifts that are project conventions, not bugs.

_Example:_ All API responses use camelCase; all DB columns use snake_case. Conversion in `services/foo/internal/serialize.go` AfterFind hook.

### Known cache layers (invalidation contract)

| Layer | Key pattern | Invalidation trigger |
|---|---|---|

---

## ERROR_HANDLING

### Approved silent fallbacks
> Cases where `.catch(() => fallback)` is intentional. Don't re-flag.

- `services/analytics/*` — tracking calls fall back silently by design

### Known unsurfaced-error hot spots
> Areas where errors are known to be swallowed but the fix is non-trivial. Track but don't re-report.

---

## ERROR_HANDLING (Phase 6 fault injection)

### Fault-injection tooling preference
_Example:_ Playwright `page.route` for SPA frontend; `nock` for Node services; `Toxiproxy` for inter-service flakiness.

### Approved fault scenarios
> Faults the user pre-authorizes for the disposable workspace. Denial-of-service patterns may need explicit per-session approval.

_Example:_ 5xx responses on any internal API; 503 on Stripe; 30s delay on Redis. Do NOT bring DB completely down without per-session approval.

---

## TEST_GAPS

### Critical paths (project's own list)
> The user-facing paths this project considers most critical.

1. ...

### Acknowledged untested areas
> Paths the team knows are untested and has chosen not to test.

### Test framework quirks
> Patterns that affect coverage interpretation.

---

## DOCS_DRIFT

### Authoritative docs (verify on every run)

- `README.md` — setup section
- `START_HERE.md` — onboarding
- `docs/operations/RUNBOOK.md`

### Known archive locations (do not flag)

- `docs/reports/.archive/`

---

## UX_DESIGN_AUDIT

### DESIGN.md location
> If non-standard.

### Allowed token deviations
> Places where deviation from DESIGN.md tokens is intentional.

- `site/legacy/*` — pre-token CSS, scheduled for migration in Q3

### Project-specific token names
> If this project uses non-standard variable names (`--brand-primary` vs `--color-primary`), note the mapping.

---

## TESTING_CREATOR (TEST_VERIFICATION)

- Preferred simulation stack (e.g., Python + Docker Compose)
- Known non-idempotent setup steps to skip or fix
