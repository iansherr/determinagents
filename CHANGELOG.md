# Changelog

All notable changes to determinagents are documented here. The format is loosely based on [Keep a Changelog](https://keepachangelog.com/), and this project follows date-based + semver-flavored versioning.

`determinagents update` shows the relevant entries when updating.

## [Unreleased]

## [0.5.0] — 2026-05-10

This release consolidates four months of in-tree work (the v0.3 harness expansion and v0.4 simplification pass referenced below were never tagged) plus a fresh batch covering installer ergonomics, the hub command flow, the rebrand to **DeterminAgents**, and shim-side quality-of-life features (doctor, completions, paste-ready uninstall cleanup).

### Added (shim — quality of life)
- `determinagents doctor` — read-only health check across install, shim, remote, and shell completion. Reports `ok` / `warn` / `fail` per check; exits non-zero on any fail. Catches stale checkouts, dirty working trees, missing PATH entries, unreachable origin, and unsupported shells before they bite during a real run.
- `determinagents completions <shell>` — prints a tab-completion script for `bash`, `zsh`, or `fish` to stdout. Single source of truth for the subcommand list lives in the shim, so adding a subcommand later only touches one place. Installer detects `$SHELL` and prints the one-liner to enable it; never edits dotfiles.
- `determinagents uninstall` now prints a paste-ready prompt for the user's LLM app to clean up generated slash commands (the shim removes the library directory; the host-tool commands live elsewhere and need an agent to remove safely).
- Shim help text rewritten so `materialize` reflects reality — one prompt, host-agnostic. The agent inside the LLM detects Claude Code / Gemini / Cursor / etc. from its own context. (Previously the help advertised a `[host]` arg that the shim silently dropped.)

### Added (installer)
- Local repository detection. If `install.sh` is run from a clone, prompts for in-place install (no network), local copy to default path, or fresh download from GitHub.
- Local-copy install option (writes a clone of the local checkout to `$DETERMINAGENTS_HOME` so the install path stays the standard one even when iterating from a clone).
- Path-baked shim for non-standard installs: when installing to a path other than `~/.determinagents`, the shim has the absolute install path baked in via `sed`, so it works without requiring `$DETERMINAGENTS_HOME` to be exported.
- Installer prints shell-specific completion-enable hint after success (no dotfile edits).

### Added (hub command — First Run flow)
- `INSTALL.md` hub template now instructs the rendering agent to stat `DESIGN.md`, `docs/determinagents/FEATURE_REGISTRY.md`, and `docs/determinagents/AUDIT_CONTEXT.md` on every invocation, and adapt the "🚀 First Run" section accordingly: omit when all three exist, demote to a single "Re-init" line when some exist, render as-is when none. The hub menu self-heals if artifacts are deleted later.
- Display-first directive: hub commands must show the menu before doing any shell commands or file searches.
- Recommendation that materialization leaves a removable marker comment (`generated-by: …/INSTALL.md`) on each generated file so uninstall is deterministic.
- Rewritten "Uninstall" section in `INSTALL.md` with the full paste-ready cleanup prompt.

### Changed (rebrand: DeterminAgents)
- Stylized as **DeterminAgents** in titles and prose (README headline, INSTALL.md hub template strings). All CLI tokens, paths, env vars, and the repo slug stay lowercase (`determinagents`, `$DETERMINAGENTS_HOME`, etc.). No code or path churn.

### Changed (README — design principle, attribution)
- New **"Design principle"** section near the top codifies *simple prompt + good harness > clever prompt + no harness*, links the v0.4 simplification commit, and includes a "when this isn't worth it" note (don't reach for a phased audit on a 200-line script). Promotes the principle from buried-in-the-Acknowledgements to a first-class framing.
- Acknowledgements rewritten: drops the Anthropic-specific name in favor of "frontier model engineers"; adds *"out loud, against the cultural reflex of secrecy and the collective instinct to grind for the perfect prompt"*; new paragraph crediting Karpathy's "loop until success criteria met" observation and Forrest Chang's [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) as a parallel distillation of the same insight.

### Fixed
- `INSTALL.md` Claude Code file-tree example had its file list duplicated in the same code block; deduped.
- Gemini CLI hub-command convention corrected to TOML (`description = "..."` + `prompt = """..."""`) — the prior example used Markdown frontmatter, which Gemini does not parse.
- Materialized commands now recommend including the absolute install path as a fallback alongside `$DETERMINAGENTS_HOME`, so commands work immediately in environments where the env var isn't exported yet.

### Added (model tier hints)
- `specs/FORMAT.md` — new "Model tier hints" section documenting three role-based, vendor-neutral tiers: `reasoning` (multi-step hypothesis generation), `default` (workhorse tasks), `fast` (narrow scope / classification). Names describe what the task needs, not what the model is, so they stay useful as model lineups change. Includes a current-mappings table (with the explicit caveat that vendor names rot).
- Each audit doc declares a `**Model tier**` line near the top. SECURITY_HUNT and TESTING_CREATOR are `reasoning`; DOCS_DRIFT and UX_DESIGN_AUDIT are `fast`; everything else `default`.
- `INSTALL.md` — documents how host-tool materialization should honor the tier hint: `model:` frontmatter where supported (Claude Code), agent-surfaced recommendation otherwise (Cursor, Gemini CLI). The materializing agent maps tier to the host's current model names.

### Changed (v0.4 simplification — applying "simple prompt + good harness" to the library itself)
- **INVOCATIONS.md cut from 590 → ~250 lines** (~57%). Collapsed enumerated invocation variants (4 RESOLVE variants, 4 SECURITY_HUNT variants, etc.) into one invocation per behavior with documented `--scope`, `--target`, `--phases`, `--max-time`, and `+harness` flags. Substituted *trust the user/agent to combine flags* for *enumerate every plausible invocation*.
- **Dropped `quick`/`standard`/`deep` named scope variants** from every audit doc. Replaced with `--phases=N,M` (run specific phases) and `--max-time=Xm` (soft budget). The agent picks based on actual constraint, not pre-baked slicing. Each audit's "Time estimate" section now states the default duration plus a one-line note about flags.
- **Split `AUDIT_CONTEXT_TEMPLATE.md` (305 lines → 63 lines)** into a minimal template (`Global` only) and a separate sections catalog (`specs/AUDIT_CONTEXT_SECTIONS.md`). New projects start with the minimal template; sections from the catalog get copied in only when there's something to put in them. Empty `## STUB_AND_COMPLETENESS` sections are noise; sections that grew during a real audit run are signal.
- **Trimmed inline invocation examples** from `specs/FEATURE_REGISTRY.md` and `specs/BOOTSTRAP.md`. Both now reference `INVOCATIONS.md` as canonical and describe the rules/shape, not the prompts.
- **RESOLVE_FROM_REPORT Phase 2** converted from 7 numbered sub-phases to a prose loop description + three sub-sections (presentation format, verification rules, commit format, report annotation). Same content, less ceremony.
- **README**: layout tree updated for new spec files; mutating-docs table includes DATA_FLOW_VERIFY; new "Inspiration" section credits Mozilla Security's Firefox-hardening writeup as the source of the agentic-harness pattern and the v0.4 simplification principle.

This is net deletion: ~700 lines removed, library shape more confidently opinionated, defaults that do the right thing rather than enumerated alternatives.

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

[Unreleased]: https://github.com/iansherr/determinagents/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/iansherr/determinagents/releases/tag/v0.5.0
[0.1.0]: https://github.com/iansherr/determinagents/releases/tag/v0.1.0
