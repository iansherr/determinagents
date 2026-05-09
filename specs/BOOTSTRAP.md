# Bootstrap: AUDIT_CONTEXT.md Generator

## Purpose

Produce or update `docs/determinagents/AUDIT_CONTEXT.md` for a project — a small overlay file that captures institutional knowledge the universal audit docs can't infer through discovery.

This is **not** a rewrite of the audit docs. The universal docs in this directory remain the source of truth. `AUDIT_CONTEXT.md` is a thin layer of project-specific calibrations that gets read alongside an audit doc on every run.

## What belongs in AUDIT_CONTEXT.md

Only things discovery cannot find:

- **Known incidents** — past bugs that revealed a pattern worth checking on every audit
- **Known false-positives** — recurring grep matches that aren't real issues; tell the agent to skip them
- **Known weak spots** — areas of the code with a higher prior probability of bugs
- **Severity calibrations** — when this project's P-levels differ from the universal rubric, and why
- **Project conventions** — opt-in vs opt-out auth, code-generation rules, naming conventions that affect grep patterns
- **Archived / dead paths** — directories the agent should ignore (`.archive/`, legacy services kept around for reference)

What does **not** belong:

- File paths discovery would find anyway (router files, frontend dirs, test layout)
- Architecture diagrams (those go in `ARCHITECTURE.md` or equivalent)
- Style/format guides (those go in `CONTRIBUTING.md`)
- Anything that would also be true after a moderate refactor — if discovery would find it next month, don't bake it in

## Two modes

### Cold bootstrap (first run)

Run when adopting these audits in a new project. The agent surveys the repo, asks the user a few targeted questions, and writes an initial `AUDIT_CONTEXT.md`.

**Prompt:**

```
Bootstrap docs/determinagents/AUDIT_CONTEXT.md for this repo, following
the spec at ${DETERMINAGENTS_HOME:-$HOME/.determinagents}/specs/BOOTSTRAP.md.

Survey the codebase: identify the auth model, deployment surface, primary
languages/frameworks, and any obvious archived/dead directories.

Then ask me up to 5 questions about institutional knowledge that wouldn't be
visible from the code alone — recent incidents, known weak spots, areas where
severity should be calibrated differently from the universal P0–P3 rubric.

Use the template at ${DETERMINAGENTS_HOME:-$HOME/.determinagents}/specs/AUDIT_CONTEXT_TEMPLATE.md.
Leave sections empty rather than inventing content. Commit the result.
```

### Warm overlay (after an audit)

Run after completing any audit. The agent proposes updates based on what was learned during the audit.

**Prompt:**

```
You just produced an audit report at docs/reports/<filename>. Propose updates
to docs/determinagents/AUDIT_CONTEXT.md based on what you learned.

Only propose entries that:
- Are project-specific institutional knowledge (not findable by discovery)
- Would change how a future audit runs (skip a path, weight a finding differently,
  flag a pattern as known)

Do not include findings themselves — those live in the report. Show me a diff
of proposed changes; don't commit until I approve.
```

## Authoring rules

When writing or updating `AUDIT_CONTEXT.md`:

- **Be terse.** Each entry is 1–3 sentences. If you need a paragraph, the entry probably belongs in the report or in real docs, not here.
- **Link, don't inline.** Reference `docs/operations/INCIDENT_2026_04.md` rather than retelling the incident.
- **Date entries.** A weak spot identified two years ago may have been fixed. `(noted 2026-04, verify still relevant)`.
- **Expire ruthlessly.** When you read an entry and it's no longer true, delete it the same turn.
- **One section per universal audit.** Plus a `Global` section for repo-wide context.

## Sections (mirror AUDIT_CONTEXT_TEMPLATE.md)

```
Global
  Auth model
  Conventions
  Archived / ignore paths
  Severity calibrations

Per-audit:
  STUB_AND_COMPLETENESS
  SECURITY_PENTEST
  DATA_FLOW_TRACE
  ERROR_HANDLING
  TEST_GAPS
  DOCS_DRIFT
  UX_DESIGN_AUDIT
  TEST_VERIFICATION
```

A section may be empty — that's fine. An empty section says "we have no special knowledge for this audit yet; run it generically."

## Anti-patterns

- **Re-stating the universal doc with paths filled in.** That's a project-specific audit doc, not an overlay. If you find yourself writing phases, stop.
- **Documenting current architecture.** That's `ARCHITECTURE.md` or `START_HERE.md`. Link to those instead.
- **"For future reference" entries.** If you can't name a specific audit run that would benefit, don't add it.
- **Listing every known TODO.** Those belong in an issue tracker.

## Maintenance

`AUDIT_CONTEXT.md` is read on every audit run. Treat it like a config file:

- Review quarterly. Delete stale entries.
- After significant refactors, audit the file before running audits.
- If an entry is wrong, the audit will produce a wrong-shaped report — so fixing the overlay is high-leverage.
