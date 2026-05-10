# Changelog

All notable changes to determinagents are documented here. The format is loosely based on [Keep a Changelog](https://keepachangelog.com/), and this project follows date-based + semver-flavored versioning.

`determinagents update` shows the relevant entries when updating.

## [Unreleased]

### Added (harness expansion — "simple prompt + good harness > clever prompt + no harness")
- `specs/FORMAT.md` — new "Harness conventions" section codifying the pattern shared by all execution-capable audits: mutating declaration, disposable workspace requirement (Phase 0.1), AUDIT_CONTEXT integration, verification loop pattern, artifact capture, "Attempted but blocked" report section, per-target scope.
- `audits/DATA_FLOW_VERIFY.md` — mutating sibling to `DATA_FLOW_TRACE.md`. Drives the actual flow (UI or API), captures real wire traffic, snapshots the DB before/after, builds the round-trip table from observed bytes. Catches silent layer drift that static analysis can't see.
- `audits/ERROR_HANDLING.md` Phase 6 — opt-in mutating fault-injection phase. Mock failures (404/500/network error) at the API boundary, drive the UI, observe what the user sees. Distinguishes silent corruption (UI lies about success) from generic-error (UI shows toast) from defended (graceful handling).
- `audits/STUB_AND_COMPLETENESS.md` Phase 6 — opt-in mutating endpoint verification. Issues real HTTP probes against suspected phantom endpoints; reclassifies false positives (proxy rewrites caught the URL) and escalates 5xx-crashing handlers to P0.
- `INVOCATIONS.md`: new §5.5 DATA_FLOW_VERIFY; `+harness` scope variant on §1.1 STUB and §1.4 ERROR_HANDLING for opt-in Phase 6.
- AUDIT_CONTEXT_TEMPLATE: new sections for `DATA_FLOW_VERIFY`, `ERROR_HANDLING (Phase 6)`, `STUB_AND_COMPLETENESS (Phase 6)` — project-specific configuration for the harness phases.
- "Harness path" subsections in `TEST_GAPS.md`, `UX_DESIGN_AUDIT.md`, `DOCS_DRIFT.md` — describes the next-level investment (mutation-testing tools / Playwright computed-style verification / clean-container code-block execution) for users who want to climb the harness ladder. Not built into these audits yet; references SECURITY_HUNT as the structural model.

### Added
- `audits/RESOLVE_FROM_REPORT.md` — mutating doc that takes any audit report and works through findings one at a time with per-finding approval, separate commits, and verification. Closes the audit→fix loop without conflating read-only and mutating sessions. Standard workflow: audit → review → resolve → re-audit.
- 4 invocation variants in `INVOCATIONS.md` §2: resolve-all-actionable, P0-only, single-finding, by-category.
- README "standard workflow" guidance describing the audit → resolve → re-audit chain.
- RESOLVE Phase 0.1 now offers commit / stash / worktree options with copy-paste commands and a recommendation matrix when a dirty tree is detected. Never auto-executes git ops.
- Universal report sections in `specs/FORMAT.md`: `## Severity rubric (this audit)` (verbatim copy of the audit's rubric, so reports are self-contained) and `## Next steps` (paste-ready RESOLVE_FROM_REPORT invocations with the report's path pre-filled).
- `audits/SECURITY_HUNT.md` — agentic vulnerability discovery with execution capability. The agent gets a disposable workspace, builds the project, generates bug hypotheses, and verifies each with a runnable testcase under sanitizers. Severity by observable defect class (UAF/OOB/type-confusion = P0), not by exploitability. Logs attempts thwarted by defenses as positive signal. Pattern and rubric drawn from Mozilla's Firefox-hardening pipeline (May 2026).
- 4 invocation variants in `INVOCATIONS.md` §5: hunt-file, hunt-function, hunt-from-pentest-report, confirmed-only-triage.
- `SECURITY_HUNT` section in `specs/AUDIT_CONTEXT_TEMPLATE.md` for project-specific configuration: build/test commands, sanitizer flags, disposable workspace convention, trust boundaries, known-blocked attack patterns, dedup history.

### Changed
- README footer attribution: "Built by [Ian Sherr](https://iansherr.com) at [Time Worthy Media](https://timeworthymedia.com)."
- `SECURITY_PENTEST.md` reframed as the static counterpart to `SECURITY_HUNT.md` — same surface, different mode. Run static first; run hunt against the high-risk targets surfaced.
- Each audit doc's Report template section now references `specs/FORMAT.md` for the universal sections, so audit-specific templates only need to define their audit-specific structure.
- RESOLVE per-finding loop now uses single-letter shorthand (`y/n/d/e/s/i/q`) instead of free-form approval. INVOCATIONS §2.1 reflects this; auto-discovery of most recent report when path omitted.

## [0.1.0] — 2026-05-09

Initial public-shaped release. The library and install flow are usable end-to-end; per-host-tool materialization is agent-driven via `INSTALL.md`.

### Audits (read-only)
- `STUB_AND_COMPLETENESS` — phantom endpoints, dead handlers, silent error swallowing, compiled-without-source files. Includes scripted phantom-endpoint cross-reference and behavioral-stub heuristic (responses without DB calls), tested against a real Go/Python/Node codebase.
- `SECURITY_PENTEST` — auth bypass, injection, IDOR, hardcoded secrets, JWT issues, infrastructure exposure.
- `DATA_FLOW_TRACE` — single-flow microscope; UI → network → handler → DB → response → cache. Field round-trip table catches the most common silent-failure cause (name/type drift across boundaries).
- `ERROR_HANDLING` — swallowed catches, logged-but-not-surfaced errors, misclassified errors. Universally underdone in most codebases.
- `TEST_GAPS` — scenario coverage (not line coverage). Critical-path matrix, mutation-test prompt, mock-quality audit.
- `DOCS_DRIFT` — README setup, architecture claims, API doc shape, code-block bitrot.
- `UX_DESIGN_AUDIT` — CSS compliance against `DESIGN.md` tokens (colors, spacing, radii, motion, typography). Requires `DESIGN.md`; bootstrap prompt provided.

### Creator (mutating)
- `TESTING_CREATOR` — four-tier verification framework: Adversarial, Chaos, Simulation, Forensics. The only doc in the library that writes code; gated behind `TEST_GAPS` and `SECURITY_PENTEST` prerequisites and explicit per-tier approval checkpoints.

### Per-project specs
- `FEATURE_REGISTRY` — spec for a per-project living catalog of every testable feature. Each project generates its own instance.
- `AUDIT_CONTEXT_TEMPLATE` — overlay skeleton for project-specific institutional knowledge (known incidents, false-positives, severity calibrations). The thing that doesn't fit in universal docs.

### Infrastructure
- `INVOCATIONS.md` — single source of truth for paste-ready prompts. Shared conventions block at top inheritable across all invocations. Covers ~17 behaviors with quick/standard/deep variants.
- `INSTALL.md` — agent-readable installer spec for materializing slash commands into Claude Code, Gemini CLI, Cursor, etc. Thin-pointer convention: materialized commands reference `$DETERMINAGENTS_HOME` paths so audit improvements flow through `determinagents update` without re-materialization.
- `install.sh` — POSIX shell installer. Honors `$DETERMINAGENTS_HOME` and `$DETERMINAGENTS_BIN`. Supports branch pinning via `--branch=`.
- `bin/determinagents` shim — CLI with `version`, `path`, `update` (shows diff before applying), `materialize`, `uninstall`, `help`.

### Conventions established
- Read-only by default for all audits; mutating docs declare it explicitly.
- Phases are independently runnable so audits can be scoped quick/standard/deep.
- Findings always include file:line and a concrete suggested fix; severity classified P0–P3 against per-doc rubrics.
- Reports go to `docs/reports/<NAME>_<YYYY-MM-DD>.md` in the target project.
- `docs/determinagents/AUDIT_CONTEXT.md` (overlay) is read first if present, to apply project-specific calibrations.

[Unreleased]: https://github.com/iansherr/determinagents/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/iansherr/determinagents/releases/tag/v0.1.0
