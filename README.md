# Self-Directed Agents

A portable library of **universal, self-discovering audit prompts** for coding agents. Hand any audit to an agent pointed at a repo; the agent discovers the project layout, runs the audit, and produces a structured report. No project-specific configuration required.

These differ from project-specific agent docs (e.g., `vostego/docs/self-directed-agents/`) in that they contain **no hardcoded paths or service names**. The agent does discovery first, then applies a universal mental model.

## Quick start

For paste-ready invocation prompts, see **[INVOCATIONS.md](INVOCATIONS.md)**.

For installing this library as slash commands or skills in your host tool (Claude Code, Gemini CLI, Cursor, etc.), see **[INSTALL.md](INSTALL.md)**.

## Layout

```
self-directed-agents/
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
│   └── TESTING_CREATOR.md   # mutating (creates code)
└── specs/               # conventions and per-project artifact specs
    ├── FORMAT.md                 # how to author a new audit
    ├── BOOTSTRAP.md              # how to generate AUDIT_CONTEXT.md
    ├── FEATURE_REGISTRY.md       # spec for the per-project feature registry
    └── AUDIT_CONTEXT_TEMPLATE.md # skeleton for the per-project overlay
```

## Available audits (read-only)

| Audit | Finds | Time |
|-------|-------|------|
| [audits/STUB_AND_COMPLETENESS.md](audits/STUB_AND_COMPLETENESS.md) | Phantom endpoints, dead handlers, silent error swallowing, compiled-without-source files | 30–90 min |
| [audits/SECURITY_PENTEST.md](audits/SECURITY_PENTEST.md) | Auth bypass, injection, IDOR, hardcoded secrets, JWT issues, exposed internals | 60–180 min |
| [audits/DATA_FLOW_TRACE.md](audits/DATA_FLOW_TRACE.md) | Where a user action breaks between UI, network, handler, and DB | 30–60 min per flow |
| [audits/ERROR_HANDLING.md](audits/ERROR_HANDLING.md) | Silent catches, missing error UI, errors logged but not surfaced | 30–60 min |
| [audits/TEST_GAPS.md](audits/TEST_GAPS.md) | Scenarios the test suite would miss — error paths, edge cases, integration boundaries | 60–90 min |
| [audits/DOCS_DRIFT.md](audits/DOCS_DRIFT.md) | Claims in README and docs that the code no longer matches | 30–60 min |
| [audits/UX_DESIGN_AUDIT.md](audits/UX_DESIGN_AUDIT.md) | CSS that violates DESIGN.md tokens — colors, spacing, radii, motion, typography | 60–120 min |

## Available creators (mutating — writes code)

| Doc | What it does | Prerequisites |
|-----|--------------|---------------|
| [audits/TESTING_CREATOR.md](audits/TESTING_CREATOR.md) | Implements tests across four tiers — Adversarial, Chaos, Simulation, Forensics — beyond what `TEST_GAPS.md` covers | Run `TEST_GAPS.md` and `SECURITY_PENTEST.md` first |

## Per-project specs

These describe an artifact each project generates its own instance of.

| Spec | Project artifact | Purpose |
|------|------------------|---------|
| [specs/FEATURE_REGISTRY.md](specs/FEATURE_REGISTRY.md) | `docs/self-directed-agents/FEATURE_REGISTRY.md` | Living catalog of every testable feature with URL, auth, steps, pass criteria, tags |
| [specs/AUDIT_CONTEXT_TEMPLATE.md](specs/AUDIT_CONTEXT_TEMPLATE.md) | `docs/self-directed-agents/AUDIT_CONTEXT.md` | Project-specific overlay (known incidents, false-positives, severity calibrations) |

Supporting docs: [specs/FORMAT.md](specs/FORMAT.md) (audit authoring spec), [specs/BOOTSTRAP.md](specs/BOOTSTRAP.md) (overlay generator workflow).

## Conventions

Every audit:

- Is **read-only** by default. The one mutating doc (`TESTING_CREATOR.md`) declares this in its purpose section.
- Has **phases** so you can scope: run Phase 1 only for a quick pass, all phases for a deep pass.
- Classifies findings by severity (**P0/P1/P2/P3**) with concrete criteria.
- Emits a report with file:line references and concrete fixes — never "fix this."
- Reports go to `docs/reports/` (in the target project) with a date-stamped name (e.g., `STUB_AUDIT_2026-05-09.md`).
- Reads `docs/self-directed-agents/AUDIT_CONTEXT.md` first if it exists, to apply project-specific calibrations.

## Companion: DESIGN.md

`audits/UX_DESIGN_AUDIT.md` assumes a `DESIGN.md` exists at the project root as the source of truth for design tokens. If your project doesn't have one, generate it first using the Google design.md spec:

- Spec & format: https://github.com/google-labs-code/design.md
- Overview: https://stitch.withgoogle.com/docs/design-md/overview/
- Format: https://stitch.withgoogle.com/docs/design-md/format/

The bootstrap prompt for DESIGN.md is in [INVOCATIONS.md](INVOCATIONS.md). The other six audits do not require DESIGN.md.
