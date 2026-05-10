# Determinagents

A portable library of **universal, self-discovering audit prompts** for coding agents. Hand any audit to an agent pointed at a repo; the agent discovers the project layout, runs the audit, and produces a structured report. No project-specific configuration required.

These differ from project-specific agent docs (the kind a team writes for one repo, hardcoding its layout) in that they contain **no hardcoded paths or service names**. The agent does discovery first, then applies a universal mental model — so the same audit works on any codebase.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/iansherr/determinagents/main/install.sh | sh
```

Installs to `~/.determinagents/` (override with `$DETERMINAGENTS_HOME`) and a `determinagents` shim to `~/.local/bin/` (override with `$DETERMINAGENTS_BIN`).

```sh
determinagents version             # what's installed
determinagents update              # check for updates, show diff, apply with confirmation
determinagents materialize         # install slash commands for your host tool
determinagents help                # full command list
```

To pin a branch (e.g., `dev` for unreleased work):

```sh
curl -fsSL https://raw.githubusercontent.com/iansherr/determinagents/dev/install.sh | sh -s -- --branch=dev
```

## First run

After installing, the lowest-friction path:

1. **Pick a repo** — yours or anyone's. The read-only audits don't modify code.
2. **Run an audit.** `STUB_AND_COMPLETENESS` is a good starter: it surfaces phantom endpoints, dead handlers, and silent failures on most codebases without needing build infrastructure. Hand this prompt to your coding agent (Claude Code, Cursor, Gemini, etc.):

   ```
   Run audits/STUB_AND_COMPLETENESS.md from $DETERMINAGENTS_HOME against
   this repo. Report to docs/reports/STUB_AUDIT_<YYYY-MM-DD>.md.
   ```

3. **Read the report** at `docs/reports/`. Every finding has a file:line, severity, and suggested fix. The report's `## Next steps` section contains paste-ready follow-up prompts.
4. **Optional next moves**: capture project-specific calibrations in `docs/determinagents/AUDIT_CONTEXT.md` so future audits skip known-false-positives (see [`specs/BOOTSTRAP.md`](specs/BOOTSTRAP.md)); or run `audits/RESOLVE_FROM_REPORT.md` to work through findings with per-finding approval and one commit per fix.

Once that loop is comfortable, browse the audits table below for other audits to try, or **[INVOCATIONS.md](INVOCATIONS.md)** for canonical paste-ready prompts. To install as slash commands in your host tool, see **[INSTALL.md](INSTALL.md)**.

## Layout

```
determinagents/
├── README.md            # this file
├── INVOCATIONS.md       # paste-ready prompts for every behavior
├── INSTALL.md           # how an agent installs this library into a host tool
├── audits/              # the runnable docs
│   ├── STUB_AND_COMPLETENESS.md
│   ├── SECURITY_PENTEST.md
│   ├── DATA_FLOW_TRACE.md
│   ├── ERROR_HANDLING.md
│   ├── TEST_GAPS.md
│   ├── DOCS_DRIFT.md
│   ├── UX_DESIGN_AUDIT.md
│   ├── RESOLVE_FROM_REPORT.md  # mutating: works through report findings
│   ├── SECURITY_HUNT.md        # mutating: agentic vulnerability hunting
│   ├── DATA_FLOW_VERIFY.md     # mutating: observed-vs-theorized data flow
│   └── TESTING_CREATOR.md      # mutating: writes new tests
└── specs/               # conventions and per-project artifact specs
    ├── FORMAT.md                  # how to author a new audit; harness conventions
    ├── BOOTSTRAP.md               # how to generate AUDIT_CONTEXT.md (cold + warm)
    ├── FEATURE_REGISTRY.md        # spec for the per-project feature registry
    ├── AUDIT_CONTEXT_TEMPLATE.md  # minimal starting overlay (Global only)
    └── AUDIT_CONTEXT_SECTIONS.md  # catalog of audit-specific sections (copy as needed)
```

## Available audits (read-only)

| Audit | Finds |
|-------|-------|
| [audits/STUB_AND_COMPLETENESS.md](audits/STUB_AND_COMPLETENESS.md) | Phantom endpoints, dead handlers, silent error swallowing, compiled-without-source files |
| [audits/SECURITY_PENTEST.md](audits/SECURITY_PENTEST.md) | Auth bypass, injection, IDOR, hardcoded secrets, JWT issues, exposed internals |
| [audits/DATA_FLOW_TRACE.md](audits/DATA_FLOW_TRACE.md) | Where a user action breaks between UI, network, handler, and DB |
| [audits/ERROR_HANDLING.md](audits/ERROR_HANDLING.md) | Silent catches, missing error UI, errors logged but not surfaced |
| [audits/TEST_GAPS.md](audits/TEST_GAPS.md) | Scenarios the test suite would miss — error paths, edge cases, integration boundaries |
| [audits/DOCS_DRIFT.md](audits/DOCS_DRIFT.md) | Claims in README and docs that the code no longer matches |
| [audits/UX_DESIGN_AUDIT.md](audits/UX_DESIGN_AUDIT.md) | CSS that violates DESIGN.md tokens — colors, spacing, radii, motion, typography |

Most audits run in 30–180 minutes at default scope, scaling with codebase size. Each audit doc supports `--phases=N,M` and `--max-time=Xm` to scope tighter.

`SECURITY_PENTEST.md` is the **static** half of security. For serious vulnerability discovery in codebases with build/test infrastructure, also use the agentic [SECURITY_HUNT.md](audits/SECURITY_HUNT.md) below.

## Available creators (mutating — writes code)

| Doc | What it does | Prerequisites |
|-----|--------------|---------------|
| [audits/RESOLVE_FROM_REPORT.md](audits/RESOLVE_FROM_REPORT.md) | Works through findings in any audit report — one at a time, with per-finding approval, separate commits, and verification | An audit report exists at `docs/reports/`; clean working tree |
| [audits/SECURITY_HUNT.md](audits/SECURITY_HUNT.md) | Agentic vulnerability hunting — agent gets execution capability to verify or refute bug hypotheses against one target file/function. Inspired by Mozilla's Firefox-hardening pipeline | Project builds locally; sanitizers configured; disposable workspace; AUDIT_CONTEXT.md `SECURITY_HUNT` section configured |
| [audits/DATA_FLOW_VERIFY.md](audits/DATA_FLOW_VERIFY.md) | Drives a real user flow end-to-end and observes wire traffic + DB state. The "observed" counterpart to `DATA_FLOW_TRACE.md`'s "inferred" — catches silent layer drift static analysis misses | Disposable workspace; app runs locally; AUDIT_CONTEXT.md `DATA_FLOW_VERIFY` section configured |
| [audits/TESTING_CREATOR.md](audits/TESTING_CREATOR.md) | Implements tests across four tiers — Adversarial, Chaos, Simulation, Forensics — beyond what `TEST_GAPS.md` covers | Run `TEST_GAPS.md` and `SECURITY_PENTEST.md` first |

Two read-only audits — `ERROR_HANDLING.md` and `STUB_AND_COMPLETENESS.md` — include an **optional mutating Phase 6** (fault injection and endpoint verification respectively) that follows the harness conventions in `specs/FORMAT.md`. Use scope `+harness` to enable.

**The standard workflow**: run an audit (read-only) → review the report → run `RESOLVE_FROM_REPORT` to work through findings → re-run the audit to verify clean state. For security-sensitive fixes, optionally chain into `TESTING_CREATOR` Tier 1 (Adversarial) afterwards to add executable coverage.

## Per-project specs

These describe an artifact each project generates its own instance of.

| Spec | Project artifact | Purpose |
|------|------------------|---------|
| [specs/FEATURE_REGISTRY.md](specs/FEATURE_REGISTRY.md) | `docs/determinagents/FEATURE_REGISTRY.md` | Living catalog of every testable feature with URL, auth, steps, pass criteria, tags |
| [specs/AUDIT_CONTEXT_TEMPLATE.md](specs/AUDIT_CONTEXT_TEMPLATE.md) | `docs/determinagents/AUDIT_CONTEXT.md` | Minimal starting overlay (Global only). Audit-specific sections come from [AUDIT_CONTEXT_SECTIONS.md](specs/AUDIT_CONTEXT_SECTIONS.md) — copied in only when filled. |

Supporting docs: [specs/FORMAT.md](specs/FORMAT.md) (audit authoring spec), [specs/BOOTSTRAP.md](specs/BOOTSTRAP.md) (overlay generator workflow).

## Conventions

Every audit:

- Is **read-only** by default. Two mutating docs (`RESOLVE_FROM_REPORT.md` and `TESTING_CREATOR.md`) declare this prominently in their purpose sections.
- Has **phases** so you can scope: run Phase 1 only for a quick pass, all phases for a deep pass.
- Classifies findings by severity (**P0/P1/P2/P3**) with concrete criteria.
- Emits a report with file:line references and concrete fixes — never "fix this."
- Reports go to `docs/reports/` (in the target project) with a date-stamped name (e.g., `STUB_AUDIT_2026-05-09.md`).
- Reads `docs/determinagents/AUDIT_CONTEXT.md` first if it exists, to apply project-specific calibrations.

## Companion: DESIGN.md

`audits/UX_DESIGN_AUDIT.md` assumes a `DESIGN.md` exists at the project root as the source of truth for design tokens. If your project doesn't have one, generate it first using the Google design.md spec:

- Spec & format: https://github.com/google-labs-code/design.md
- Overview: https://stitch.withgoogle.com/docs/design-md/overview/
- Format: https://stitch.withgoogle.com/docs/design-md/format/

The bootstrap prompt for DESIGN.md is in [INVOCATIONS.md](INVOCATIONS.md). The other six audits do not require DESIGN.md.

## Acknowledgements

Thank you to Mozilla Security for publicly sharing **[Behind the Scenes: Hardening Firefox](https://hacks.mozilla.org/2026/05/behind-the-scenes-hardening-firefox/)** (May 2026). Their description of the agentic-harness pipeline, the inner-loop framing — *"there is a bug in this part of the code, please find it and build a testcase"* — and the severity-by-defect-class rubric directly shaped `audits/SECURITY_HUNT.md` and the broader v0.3 / v0.4 design. Open writeups from teams doing real production work like this is how the rest of us learn.

Thank you also to the engineers at Anthropic and elsewhere who keep saying — out loud, against the cultural reflex to grind for the perfect prompt — that working *with* an agent to improve a prompt produces better prompts than working alone. This library is an outgrowth of that practice: a personal collection of prompts that worked, refined over time, until the scaffolds of a standard set became visible. The spec emerged from the pattern, not the other way around. The hope now is that publishing it helps others skip a few of the same steps.

---

Orchestrated by [Ian Sherr](https://iansherr.com) at [Time Worthy Media](https://timeworthymedia.com).

