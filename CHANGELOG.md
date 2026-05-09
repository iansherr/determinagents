# Changelog

All notable changes to determinagents are documented here. The format is loosely based on [Keep a Changelog](https://keepachangelog.com/), and this project follows date-based + semver-flavored versioning.

`determinagents update` shows the relevant entries when updating.

## [Unreleased]

### Added
- `audits/RESOLVE_FROM_REPORT.md` — mutating doc that takes any audit report and works through findings one at a time with per-finding approval, separate commits, and verification. Closes the audit→fix loop without conflating read-only and mutating sessions. Standard workflow: audit → review → resolve → re-audit.
- 4 invocation variants in `INVOCATIONS.md` §2: resolve-all-actionable, P0-only, single-finding, by-category.
- README "standard workflow" guidance describing the audit → resolve → re-audit chain.

### Changed
- README footer attribution: "Built by [Ian Sherr](https://iansherr.com) at [Time Worthy Media](https://timeworthymedia.com)."

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
