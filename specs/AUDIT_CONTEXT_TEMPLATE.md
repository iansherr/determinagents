# Audit Context — <PROJECT NAME>

> Project-specific overlay for the universal audits in `${DETERMINAGENTS_HOME:-$HOME/.determinagents}/`.
> Read this file before running any audit. See `specs/BOOTSTRAP.md` for what belongs here.
>
> **Last reviewed:** YYYY-MM-DD

This minimal template starts with `Global` only. Add audit-specific sections from `specs/AUDIT_CONTEXT_SECTIONS.md` as you fill them in — don't copy them empty.

---

## Global

### Auth model

> 1–3 sentences. Where does authn happen? Where does authz happen? Opt-in or opt-out per route? Anything that changes how a security or data-flow audit should treat "unprotected" routes.

_Example:_ Auth is enforced by a middleware applied per-route (opt-in). Any new route is unauthenticated by default — treat as P1 unless explicitly meant to be public.

### Conventions

> Project-specific patterns that affect grep / discovery. JSONB hydration, custom RPC layer, code-generation directories, monorepo workspace layout, etc.

_Example:_ JSONB columns are hydrated via GORM `AfterFind` hooks. A column's app-level shape may differ from its DB shape — always check both.

### Archived / ignore paths

> Directories the agent should not audit.

```
.archive/
backups/
services/legacy-foo/
site/source/assets/js/*.compiled.js
```

### Severity calibrations

> Where this project's P-levels differ from the universal rubric, and why.

_Example:_ Admin-panel gaps are P1, not P0 — admins report breakage out-of-band; these endpoints aren't hit by end users.

### Recent incidents (worth knowing)

| Date | Incident | Pattern to watch | Reference |
|---|---|---|---|
| 2026-04 | (example) Phantom admin endpoints | `.catch(() => fallback)` masking 404s | `docs/operations/ADMIN_PANEL_FIXING_GUIDE.md` |

---

## (audit-specific sections — copy from `specs/AUDIT_CONTEXT_SECTIONS.md` as needed)

Section catalog: `STUB_AND_COMPLETENESS`, `SECURITY_PENTEST`, `DATA_FLOW_TRACE`, `ERROR_HANDLING`, `TEST_GAPS`, `DOCS_DRIFT`, `UX_DESIGN_AUDIT`, `SECURITY_HUNT`, `DATA_FLOW_VERIFY`, `STUB_AND_COMPLETENESS (Phase 6)`, `ERROR_HANDLING (Phase 6)`, `TESTING_CREATOR`.

Don't add sections preemptively. An empty `## STUB_AND_COMPLETENESS` section is noise — and a section that grew during a real audit run is signal.

---

## Notes for the agent

- An empty section means "no special knowledge." Run the audit generically.
- If you discover a pattern during an audit that would belong here, propose a new section per the warm-overlay flow in `specs/BOOTSTRAP.md`.
- Do not duplicate content that lives in `ARCHITECTURE.md`, `START_HERE.md`, `CONTRIBUTING.md`, or the universal audit docs. Link instead.
