# Audit Context — DeterminAgents Library Repo

> Project-specific overlay for the universal audits in `${DETERMINAGENTS_HOME:-$HOME/.determinagents}/`.

## Global

**Project type**: Library of markdown prompt files and a POSIX shell installer/shim. There is no application code, no API, no database, no frontend, and no build step.

**Executables**: `bin/determinagents` (POSIX sh, not bash — shellcheck CI enforces this) and `install.sh` (same). The only other files are markdown docs and a test Dockerfile.

**`docs/` directory**: the `docs/determinagents/` and `docs/reports/` paths referenced throughout the audit docs are paths in *target projects* that users run these audits against. This repo has its own `docs/` for library-internal artifacts (this file, maintenance reports). Do not conflate the two.

**Reports**: standard audit reports go to `docs/reports/` per convention. Maintenance runs (`specs/MAINTENANCE.md`) go to `docs/maintenance/` (gitignored).

**False positives to suppress**:
- Any finding about missing API endpoints, auth handlers, database calls, or frontend assets — this repo has none of these.
- References to `docs/determinagents/AUDIT_CONTEXT.md` not existing — it exists; you're reading it.

**Audits that apply meaningfully to this repo**:
- `DOCS_DRIFT.md` — do README / INSTALL.md / CHANGELOG claims match what's in the files?
- `STUB_AND_COMPLETENESS.md` — are any docs cross-referenced but missing?

**Audits that don't apply**:
- `SECURITY_PENTEST.md`, `DATA_FLOW_TRACE.md`, `ERROR_HANDLING.md`, `UX_DESIGN_AUDIT.md` — no attack surface, no data flow, no UI.
- `TEST_GAPS.md` — the only tests are a CI shellcheck pass and an install smoke-test in Docker; no unit/integration suite exists by design.
